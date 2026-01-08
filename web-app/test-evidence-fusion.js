/**
 * Simple test runner for Evidence-Based Fusion System
 */

const { runEvidenceFusionTests } = require('./src/tests/evidence-fusion-test.ts');

// Run the tests
runEvidenceFusionTests()
  .then(() => {
    console.log('\n✅ All tests completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Tests failed with error:', error);
    process.exit(1);
  });