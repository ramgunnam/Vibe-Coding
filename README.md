# Apex Cursors - Complex Implementation Scenario

A comprehensive Salesforce implementation demonstrating the full power of **Apex Cursors** (GA in API v66.0, Spring '26) for enterprise-scale data processing.

## Scenario: Global Data Quality & Compliance Processing Engine

This implementation showcases a complex, real-world use case for Apex Cursors - an enterprise-wide data quality assessment and remediation system that processes millions of records across multiple objects.

### Why Apex Cursors?

Apex Cursors solve critical limitations of traditional approaches:

| Feature | Batch Apex | Apex Cursors |
|---------|------------|--------------|
| Maximum Records | 50M per job | 50M per cursor |
| Bidirectional Navigation | No | Yes |
| Flexible Chunk Sizes | Fixed batch size | Dynamic, any size |
| Position Control | Sequential only | Random access |
| Queueable Integration | Limited | Native support |
| Cursor Persistence | N/A | 48 hours |
| UI Pagination | Complex workarounds | Built-in support |

### Key Capabilities Demonstrated

#### 1. Multi-Cursor Orchestration
Process Accounts, Contacts, Opportunities, and Cases simultaneously with coordinated cursors:

```apex
// Initialize cursors for multiple objects
accountCursor = Database.getCursor(accountQuery);
contactCursor = Database.getCursor(contactQuery);
opportunityCursor = Database.getCursor(opportunityQuery);
caseCursor = Database.getCursor(caseQuery);
```

#### 2. Bidirectional Traversal
Process records in any order - forwards, backwards, or jump to specific positions:

```apex
// Process newest records first (backwards)
Integer position = totalRecords - batchSize;
while (position >= 0) {
    List<SObject> records = cursor.fetch(position, batchSize);
    // Process records
    position -= batchSize;
}
```

#### 3. Queueable Chaining with Cursor State
Chain multiple Queueable jobs while maintaining cursor state:

```apex
public class DataProcessor implements Queueable {
    private Database.Cursor cursor;
    private Integer position;

    public void execute(QueueableContext context) {
        List<Account> records = cursor.fetch(position, 200);
        position += records.size();

        if (hasMoreRecords()) {
            System.enqueueJob(this); // Chain with same cursor
        }
    }
}
```

#### 4. Dynamic Cursor Creation with Bind Variables
Create cursors dynamically based on runtime conditions:

```apex
Map<String, Object> bindMap = new Map<String, Object>{
    'industryBind' => new List<String>{'Technology', 'Finance'},
    'countryBind' => 'USA'
};

Database.Cursor cursor = Database.getCursorWithBinds(
    'SELECT Id FROM Account WHERE Industry IN :industryBind AND BillingCountry = :countryBind',
    bindMap,
    AccessLevel.USER_MODE
);
```

#### 5. Adaptive Load Balancing
Dynamically adjust batch sizes based on CPU limits and record complexity:

```apex
// Check remaining CPU time
Decimal cpuUsagePercent = (Decimal)Limits.getCpuTime() / Limits.getLimitCpuTime();

if (cpuUsagePercent > 0.70) {
    currentBatchSize = (Integer)(currentBatchSize * 0.75); // Reduce
} else if (cpuUsagePercent < 0.50) {
    currentBatchSize = (Integer)(currentBatchSize * 1.25); // Increase
}
```

#### 6. Platform Cache Integration
Store cursors in Platform Cache for cross-transaction access:

```apex
// Store cursor (valid for 48 hours)
Cache.Org.put('cursor_' + jobId, cursor, 172800);

// Restore cursor in subsequent transaction
Database.Cursor cursor = (Database.Cursor)Cache.Org.get('cursor_' + jobId);
```

#### 7. Real-Time Monitoring via Platform Events
Track processing progress in real-time:

```apex
Data_Quality_Progress__e progressEvent = new Data_Quality_Progress__e(
    Job_Id__c = jobId,
    Accounts_Processed__c = accountsProcessed,
    Status__c = 'Processing'
);
EventBus.publish(progressEvent);
```

## Project Structure

```
force-app/main/default/
├── classes/
│   ├── DataQualityCursorOrchestrator.cls      # Main processing engine
│   ├── MultiCursorCoordinationService.cls      # Advanced cursor patterns
│   ├── DataQualityPaginationController.cls     # LWC controller
│   └── *Test.cls                               # Test classes
├── lwc/
│   └── dataQualityDashboard/                   # Real-time monitoring UI
├── objects/
│   ├── Data_Quality_Job__c/                    # Job tracking
│   ├── Data_Quality_Issue__c/                  # Issue storage
│   └── Duplicate_Record__c/                    # Duplicate tracking
└── platformEvents/
    └── Data_Quality_Progress__e/               # Real-time progress events
```

## Processing Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `FULL_SCAN` | Process all records | Initial data quality assessment |
| `INCREMENTAL` | Last 7 days only | Daily maintenance runs |
| `HIGH_PRIORITY_FIRST` | Backwards from newest, high-value | Critical account processing |
| `COMPLIANCE_AUDIT` | EU/regulated industries focus | GDPR/regulatory compliance |
| `DUPLICATE_DETECTION` | Fuzzy matching focus | Data deduplication projects |

## Cursor Limits (API v66.0)

- **Max records per cursor**: 50 million
- **Max cursors per day**: 10,000
- **Max aggregate rows per day**: 100 million
- **Cursor lifetime**: 48 hours
- **Max fetch calls per transaction**: 10

## Usage Example

```apex
// Start a new data quality job
DataQualityCursorOrchestrator orchestrator =
    new DataQualityCursorOrchestrator(
        DataQualityCursorOrchestrator.ProcessingMode.FULL_SCAN
    );

Id jobId = System.enqueueJob(orchestrator);

// Resume a paused job
DataQualityCursorOrchestrator resumedOrchestrator =
    new DataQualityCursorOrchestrator('DQ-1234567890-123456');

System.enqueueJob(resumedOrchestrator);
```

## Deployment

```bash
sf project deploy start --source-dir force-app
```

## Resources

- [Apex Cursors Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_cursors.htm)
- [Cursor Class Reference](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Database_Cursor.htm)
- [Spring '26 Release Notes](https://help.salesforce.com/s/articleView?id=release-notes.rn_apex_ApexCursors.htm)

## License

MIT License
