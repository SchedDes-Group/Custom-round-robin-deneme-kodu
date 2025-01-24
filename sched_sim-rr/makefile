ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
UNWANTED_DIRS := .git

all:
	matlab -nosplash -nodesktop -r "rootPath = genpath('${ROOT_DIR}'); unwantedDirs = {$(foreach dir,$(UNWANTED_DIRS),'${ROOT_DIR}$(dir)',)}; for i = 1:length(unwantedDirs),rootPath = strrep(rootPath, [unwantedDirs{i} pathsep], ''); end; addpath(rootPath); run('${ROOT_DIR}simulation.m');"
