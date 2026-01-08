// Debug Date serialization issue

console.log('🔍 Debugging Date Serialization Issue');
console.log('====================================');

// Simulate the extraction result with different date formats
const testResults = [
  {
    name: 'Date Object Result',
    result: {
      date: new Date('05/30/2020 12:20 AM'),
      merchant_name: 'Test Store'
    }
  },
  {
    name: 'String Date Result (YYYY-MM-DD)',
    result: {
      date: '2020-05-30',
      merchant_name: 'Test Store'
    }
  },
  {
    name: 'String Date Result (ISO format)', 
    result: {
      date: '2020-05-29T21:00:00.000Z',
      merchant_name: 'Test Store'
    }
  }
];

console.log('Original date string: "05/30/2020 12:20 AM"');
console.log('Expected output: "2020-05-30"');
console.log('');

testResults.forEach(test => {
  console.log(`📋 Testing: ${test.name}`);
  console.log(`  Original date value:`, test.result.date);
  console.log(`  Type:`, typeof test.result.date);
  
  // Show what happens when JSON.stringify is called
  const stringified = JSON.stringify(test.result);
  console.log(`  After JSON.stringify:`, stringified);
  
  // Parse it back
  const parsed = JSON.parse(stringified);
  console.log(`  After JSON.parse:`, parsed.date);
  console.log(`  Correct (2020-05-30)?:`, parsed.date === '2020-05-30' ? '✅' : '❌');
  console.log('');
});

console.log('🎯 Conclusion:');
console.log('When Date objects are JSON.stringify\'d, they automatically get converted to ISO string format.');
console.log('This causes the UTC conversion issue we\'re seeing.');