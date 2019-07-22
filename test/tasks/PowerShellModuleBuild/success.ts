import * as ma from 'azure-pipelines-task-lib/mock-answer';
import * as tmrm from 'azure-pipelines-task-lib/mock-run';
import { taskIndexPath } from './common';

const tmr: tmrm.TaskMockRunner = new tmrm.TaskMockRunner(taskIndexPath);
tmr.setInput('samplestring', 'human');
tmr.run();
