% Question => (% >)(\n.*?)+(% <)
% Change => (% {)(\n.*?)+(% })
% Probably irrelevant => (% irr)(\n.*?)+(% rri)
classdef helperNRRoundRobinSchedulingStrategy < nrScheduler
    %helperNRCustomSchedulingStrategy Implements the custom uplink(UL) and downlink(DL) scheduling strategy
    % This class implements scheduling strategy to allocate resources for new
    % transmissions among User Equipments (UEs) with varying priorities. In
    % each scheduled slot, scheduling strategy randomly selects high priority
    % UEs and allots fixed number of Resource Blocks (RBs). After serving
    % high priority UEs, the remaining RBs are distributed equally among low
    % priority UEs. The same strategy is used for both UL and DL directions.

    %   Copyright 2024 The MathWorks, Inc.

    properties (Access=private)
        %NumRBHighPriority The fixed number of RBs allocated to a high priority UE in a DL assignment or a UL grant.
        % If free RBs are lesser than NumRBHighPriority, then all the free RBs are
        % allotted to a randomly selected high priority UE
        NumRB = 4;

        %StatAllottedRBHighPriority Cumulative number of the RBs allotted to high priority UEs.
        % This only includes allotted RBs for new transmissions. A vector of two
        % elements. First and second elements represent the total number of
        % allotted RBs in downlink and uplink directions respectively.
        StatAllottedRB = zeros(1, 2);

    end

    properties(Constant)
        %CQITable CQI table as per TS 38.214 - Table 5.2.2.1-3.
        % This table is used to indicate channel quality for DL direction
        % Modulation CodeRate Efficiency
        CQITable = [0    0   0
            2   78      0.1523
            2   193     0.3770
            2   449     0.8770
            4   378     1.4766
            4   490     1.9141
            4   616     2.4063
            6   466     2.7305
            6   567     3.3223
            6   666     3.9023
            6   772     4.5234
            6   873     5.1152
            8   711     5.5547
            8   797     6.2266
            8   885     6.9141
            8   948     7.4063];

        %MCSTable MCS table as per TS 38.214 - Table 5.1.3.1-2.
        % This table is used to indicate MCS for both UL and DL directions
        % Modulation CodeRate Efficiency
        MCSTable = [2	120	0.2344
            2	193     0.3770
            2	308     0.6016
            2	449     0.8770
            2	602     1.1758
            4	378     1.4766
            4	434     1.6953
            4	490     1.9141
            4	553     2.1602
            4	616     2.4063
            4	658     2.5703
            6	466     2.7305
            6	517     3.0293
            6	567     3.3223
            6	616     3.6094
            6	666     3.9023
            6	719     4.2129
            6	772     4.5234
            6	822     4.8164
            6	873     5.1152
            8	682.5	5.3320
            8	711     5.5547
            8	754     5.8906
            8	797     6.2266
            8	841     6.5703
            8	885     6.9141
            8	916.5	7.1602
            8	948     7.4063
            2    0       0
            4    0       0
            6    0       0
            8    0       0];
    end

    methods
        function obj = helperNRCustomSchedulingStrategy(varargin)
            %helperNRCustomSchedulingStrategy Initialize the custom scheduler class
            %   helperNRCustomSchedulingStrategy properties (configurable through N-V pair):
            %
            %   NumRBHighPriority - The fixed number of RBs allocated to a high
            %   priority UE in a DL assignment or a UL grant.

            % Name-value pair check
            coder.internal.errorIf(mod(nargin, 2) == 1,'MATLAB:system:invalidPVPairs');
            if nargin == 2
                obj.(varargin{1}) = varargin{2};
            end
        end

        function stat = getAllottedRBCount(obj)
            %getAllottedRBCount Get the total number of allotted RBs for high priority UEs and low priority UEs in downlink and uplink directions.
            % This only includes allotted RBs for new transmissions.

            % Two elements vector which represents the total number of allotted RBs for
            % high and low priority UEs in downlink and uplink directions respectively
            % {
            stat = obj.StatAllottedRB;
            % }
        end
    end

    methods (Access = protected)
        function ulGrants = scheduleNewTransmissionsUL(obj, timeResource, frequencyResource, schedulingInfo)
            %scheduleNewTransmissionsUL Assign resources for new UL transmissions in a transmission time interval (TTI)
            %
            %   ULGRANTS is a struct array where each element represents one UL grant.Refer <a href="matlab:help('nrScheduler.scheduleNewTransmissionsUL')">scheduleNewTransmissionsUL</a>
            %   for more information on the grant fields to be filled in this function. The remaining grant fields are
            %   filled by the caller of this function.


            % Read eligible UEs. For more information about eligible UEs, see the
            % scheduleNewTransmissionsUL method of nrScheduler class.
            eligibleUEs = schedulingInfo.EligibleUEs;
            % {
            maxNumUsersTTI = schedulingInfo.MaxNumUsersTTI;
            % }
            ueContext = obj.UEContext;

            % irr
            % Stores UL grants of this TTI
            ulGrantStruct = struct('RNTI',[],'FrequencyAllocation',[], ...
                'MCSIndex',[],'NumLayers',[],'TPMI',[]);
            ulGrants = repmat(ulGrantStruct,numel(eligibleUEs),1);
            % rri

            % {
            selectedUEs = eligibleUEs(1:min(maxNumUsersTTI, numel(eligibleUEs)));
            % }

            % >
            % Find index of the first free RB in the bandwidth. The retransmission
            % grants (if any) use contiguous RBs from start of the bandwidth hence all
            % the RBs after the first free RB are available for new transmission.

            firstFreeRBIndex = find(frequencyResource==0, 1)-1;
            numRBs = obj.CellConfig.NumResourceBlocks;
            numAllottedGrants = 0;
            % <

            % >
            % Allocate fixed number of RBs to high priority UEs. If free RBs are lesser
            % than NumRBHighPriority, then allocate all the free RBs to the selected UE
            for i=1:numel(selectedUEs)
                remFreeRBs = numRBs - firstFreeRBIndex;
                allottedRBCount = min(remFreeRBs, obj.NumRB);
                % Fill the new transmission uplink grant properties
                % {
                selectedSingleUE = selectedUEs(i);
                ueInfo = ueContext(selectedSingleUE);
                % }
                csiMeasurement = ueInfo.CSIMeasurementUL;
                % {
                ulGrants(i).RNTI = selectedSingleUE;
                % }
                ulGrants(i).FrequencyAllocation = [firstFreeRBIndex allottedRBCount];
                % Use SRS based channel measurement report to fill MCSIndex, NumLayers and TPMI
                ulGrants(i).MCSIndex = csiMeasurement.MCSIndex;
                ulGrants(i).NumLayers = csiMeasurement.RI;
                ulGrants(i).TPMI = csiMeasurement.TPMI;
                % Update the stats
                obj.StatAllottedRB(1) = obj.StatAllottedRB(1) + allottedRBCount;
                numAllottedGrants = numAllottedGrants + 1;
                firstFreeRBIndex = firstFreeRBIndex + allottedRBCount;
                if firstFreeRBIndex == numRBs
                    break; % All RBs are allotted
                end
                % <
            end

            ulGrants = ulGrants(1:numAllottedGrants); % Remove invalid trailing entries
        end

        function dlAssignments = scheduleNewTransmissionsDL(obj, timeResource, frequencyResource, schedulingInfo)
            %scheduleNewTransmissionsDL Assign resources for new DL transmissions in a transmission time interval (TTI)
            %
            %   DLASSIGNMENTS is a struct array where each element represents DL assignment. Refer <a href="matlab:help('nrScheduler.scheduleNewTransmissionsDL')">scheduleNewTransmissionsDL</a>
            %  for more information on the assignment fields to be filled in this function. The remaining assignment fields
            %  are filled by the caller of this function.

            % Read eligible UEs. For more information about eligible UEs, see the
            % scheduleNewTransmissionsDL method of nrScheduler class.
            eligibleUEs = schedulingInfo.EligibleUEs;
            maxNumUsersTTI = schedulingInfo.MaxNumUsersTTI;
            ueContext = obj.UEContext;

            % Stores DL assignments of this TTI
            dlAssignmentStruct = struct('RNTI',[],'FrequencyAllocation',[], 'MCSIndex',[], 'W',[]);
            dlAssignments = repmat(dlAssignmentStruct, numel(eligibleUEs), 1);

            selectedUEs = eligibleUEs(1:min(maxNumUsersTTI, numel(eligibleUEs)));

            % Find index of the first free RB in the bandwidth. The retransmission
            % assignments (if any) use contiguous RBs from start of the bandwidth hence
            % all the RBs after the first free RB are available for new transmission.
            firstFreeRBIndex = find(frequencyResource==0, 1)-1;
            numRBs = obj.CellConfig.NumResourceBlocks;
            numAllottedAssignments = 0;
            % Allocate fixed number of RBs to high priority UEs. If free RBs are lesser
            % than NumRBHighPriority, then allocate all the free RBs to the selected UE
            for i=1:numel(selectedUEs)
                remFreeRBs = numRBs - firstFreeRBIndex;
                allottedRBCount = min(remFreeRBs, obj.NumRB);
                % Fill the new transmission downlink assignment properties
                selectedSingleUE = selectedUEs(i);
                csiMeasurement = ueContext(selectedSingleUE).CSIMeasurementDL;
                csiMeasurementCQI = csiMeasurement.CSIRS.CQI;
                dlAssignments(i).RNTI = selectedSingleUE;
                dlAssignments(i).FrequencyAllocation = [firstFreeRBIndex allottedRBCount];
                % Use CSI-RS based channel measurement report to fill MCSIndex and W
                dlAssignments(i).MCSIndex = getMCS(obj, csiMeasurementCQI);
                % CSI-RS reported W matrix has dimension NumPorts-by-NumLayers.
                % Transposing it to get required dimension NumLayers-by-NumPorts.
                dlAssignments(i).W = csiMeasurement.CSIRS.W.';
                % Update the stats
                obj.StatAllottedRB(2) = obj.StatAllottedRB(2) + allottedRBCount;
                numAllottedAssignments = numAllottedAssignments + 1;
                firstFreeRBIndex = firstFreeRBIndex + allottedRBCount;
                if firstFreeRBIndex == numRBs
                    break; % All RBs are allotted
                end
            end

            dlAssignments = dlAssignments(1:numAllottedAssignments); % Remove invalid trailing entries
        end
    end

    methods (Access = private)
        function mcsRowIndex = getMCS(obj, cqiIndex)
            %getMCS Returns the MCS row index

            cqiTable = obj.CQITable;
            mcsTable = obj.MCSTable;
            modulation = cqiTable(cqiIndex + 1, 1);
            codeRate = cqiTable(cqiIndex + 1, 2);
            for mcsRowIndex = 1:28 % MCS indices
                if modulation ~= mcsTable(mcsRowIndex, 1)
                    continue;
                end
                if codeRate <= mcsTable(mcsRowIndex, 2)
                    break;
                end
            end
            mcsRowIndex = mcsRowIndex - 1;
        end
    end
end