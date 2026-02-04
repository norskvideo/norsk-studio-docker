const { expect } = require('chai');
const {
  startStudio,
  stopStudio,
  waitForWorkflowRunning,
  getLiveComponents
} = require('./helpers');

// All built-in workflows with expected component counts
const WORKFLOWS = [
  { name: '00-File-to-CMAF.yaml', minComponents: 2 },
  { name: '01-SRT-to-HLS-Ladder.yaml', minComponents: 3 },
  { name: '02-Test-Card.yaml', minComponents: 2 },
  { name: '03-SRT-to-WebRTC.yaml', minComponents: 2 },
  { name: '04-SRT-to-HLS-Ladder-and-WebRTC.yaml', minComponents: 4 },
  { name: '05-SRT-to-HLS-Ladder-with-On-Screen-Graphic.yaml', minComponents: 4 },
  { name: '06-Source-Switcher-to-HLS-Ladder.yaml', minComponents: 4 },
  { name: '07-Vision-Director.yaml', minComponents: 3 }
];

describe('Built-in Workflows', function() {
  this.timeout(180000);

  WORKFLOWS.forEach(({ name, minComponents }) => {
    describe(name, function() {
      after(async function() {
        await stopStudio();
      });

      it('loads and runs successfully', async function() {
        await startStudio(`--workflow ${name}`);
        await waitForWorkflowRunning();

        const data = await getLiveComponents();
        expect(data.totalComponents).to.be.at.least(minComponents);
      });
    });
  });
});
