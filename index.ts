import * as task from 'azure-pipelines-task-lib';

async function run() {
    try {
        const inputString: string = task.getInput('samplestring', true);

        if (inputString === 'bad') {
            task.setResult(task.TaskResult.Failed, 'Bad input was given');
            return;
        }

        console.log(`Input: ${inputString}`);
    }
    catch (err) {
        task.setResult(task.TaskResult.Failed, err.message);
    }
}

run();