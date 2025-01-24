wirelessnetworkSupportPackageCheck

rng("default")           % Reset the random number generator
numFrameSimulation = 30; % Simulation time in terms of number of 10 ms frames
networkSimulator = wirelessNetworkSimulator.init;

gNB = nrGNB(Position=[0 0 10],CarrierFrequency=2.6e9,ChannelBandwidth=5e6,SubcarrierSpacing=15e3,ReceiveGain=11, ...
    NumTransmitAntennas=16,NumReceiveAntennas=8);

scheduler = helperNRCustomSchedulingStrategy();
configureScheduler(gNB,Scheduler=scheduler);

numUEs = 8;
uePositions = [randi([0 250],numUEs,2) ones(numUEs,1)];
ueNames = "UE-" + (1:size(uePositions,1));
UEs = nrUE(Name=ueNames,Position=uePositions);

connectUE(gNB,UEs(1:numUEs),CustomContext=struct(Priority=1),FullBufferTraffic='on')

addNodes(networkSimulator,gNB)
addNodes(networkSimulator,UEs)

% Model an urban macro scenario, as defined in the 3GPP TR 38.901 channel
% model, using the h38901Channel object.

% Define scenario boundaries
pos = reshape([gNB.Position UEs.Position],3,[]);
minX = min(pos(1,:));          % x-coordinate of the left edge of the scenario in meters
minY = min(pos(2,:));          % y-coordinate of the bottom edge of the scenario in meters
width = max(pos(1,:)) - minX;  % Width (distance from left to right edge of the 2-D scenario) in meters, given as maxX - minX
height = max(pos(2,:)) - minY; % Height (distance from bottom to top edge of the 2-D scenario) in meters, given as maxY - minY

% Create the channel model
channel = h38901Channel(Scenario="UMa",ScenarioExtents=[minX minY width height]);
% Add the channel model to the simulator
addChannelModel(networkSimulator,@channel.channelFunction)
connectNodes(channel,networkSimulator)

enableTraces = true;

if enableTraces
    % Create an object to log scheduler traces
    simSchedulingLogger = helperNRSchedulingLogger(numFrameSimulation,gNB,UEs);
    % Create an object to log PHY traces
    simPhyLogger = helperNRPhyLogger(numFrameSimulation,gNB,UEs);
end

numMetricPlotUpdates = numFrameSimulation;

metricsVisualizer = helperNRMetricsVisualizer(gNB,UEs,NumMetricsSteps=numMetricPlotUpdates, ...
    PlotSchedulerMetrics=true,PlotPhyMetrics=true);

simulationLogFile = "simulationLogs"; % For logging the simulation traces

% Calculate the simulation duration (in seconds)
simulationTime = numFrameSimulation * 1e-2;
% Run the simulation
run(networkSimulator,simulationTime);
