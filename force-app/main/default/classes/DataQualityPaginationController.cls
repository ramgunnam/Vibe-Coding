/**
 * @description LWC Controller for Data Quality Dashboard with Pagination Cursors
 *
 * This controller demonstrates the new PaginationCursor class (GA in Spring '26)
 * specifically designed for UI pagination scenarios.
 *
 * Key Features:
 * - Bidirectional navigation (next/previous pages)
 * - Efficient large dataset handling
 * - Session-scoped cursor persistence
 * - Real-time progress monitoring via Platform Events
 */
public with sharing class DataQualityPaginationController {

    private static final Integer DEFAULT_PAGE_SIZE = 50;
    private static final String CACHE_KEY_PREFIX = 'DQP_';

    /**
     * @description Start a new data quality analysis job
     * @param mode The processing mode to use
     * @return Job ID for tracking
     */
    @AuraEnabled
    public static String startDataQualityJob(String mode) {
        try {
            DataQualityCursorOrchestrator.ProcessingMode processingMode =
                DataQualityCursorOrchestrator.ProcessingMode.valueOf(mode);

            DataQualityCursorOrchestrator orchestrator =
                new DataQualityCursorOrchestrator(processingMode);

            Id jobId = System.enqueueJob(orchestrator);
            return String.valueOf(jobId);
        } catch (Exception e) {
            throw new AuraHandledException('Failed to start job: ' + e.getMessage());
        }
    }

    /**
     * @description Resume a failed or paused job
     * @param jobId The job ID to resume
     * @return New Queueable job ID
     */
    @AuraEnabled
    public static String resumeDataQualityJob(String jobId) {
        try {
            DataQualityCursorOrchestrator orchestrator =
                new DataQualityCursorOrchestrator(jobId);

            Id newJobId = System.enqueueJob(orchestrator);
            return String.valueOf(newJobId);
        } catch (Exception e) {
            throw new AuraHandledException('Failed to resume job: ' + e.getMessage());
        }
    }

    /**
     * @description Get paginated list of data quality issues using PaginationCursor
     * @param pageSize Number of records per page
     * @param cursorState Serialized cursor state for navigation
     * @param direction Navigation direction: 'next', 'previous', or 'first'
     * @return PaginatedResult with issues and navigation state
     */
    @AuraEnabled(cacheable=false)
    public static PaginatedResult getDataQualityIssues(
        Integer pageSize,
        String cursorState,
        String direction
    ) {
        try {
            pageSize = pageSize != null ? pageSize : DEFAULT_PAGE_SIZE;

            // Define the query for issues
            String issueQuery = 'SELECT Id, Record_Id__c, Object_Type__c, Issue_Type__c, ' +
                               'Description__c, Severity__c, Job_Id__c, Detected_Date__c, ' +
                               'CreatedDate, Status__c ' +
                               'FROM Data_Quality_Issue__c ' +
                               'WHERE Status__c != \'Resolved\' ' +
                               'ORDER BY Severity__c DESC, CreatedDate DESC';

            Database.Cursor cursor;
            Integer position = 0;

            // Handle cursor restoration or creation
            if (String.isNotBlank(cursorState)) {
                // Restore cursor from session cache
                cursor = (Database.Cursor)Cache.Session.get(CACHE_KEY_PREFIX + 'issues');
                position = Integer.valueOf(cursorState);

                // Adjust position based on direction
                if (direction == 'next') {
                    position += pageSize;
                } else if (direction == 'previous') {
                    position = Math.max(0, position - pageSize);
                }
            } else {
                // Create new cursor
                cursor = Database.getCursor(issueQuery);
                Cache.Session.put(CACHE_KEY_PREFIX + 'issues', cursor);
            }

            // Fetch records for current page
            List<Data_Quality_Issue__c> issues = cursor.fetch(position, pageSize);
            Integer totalRecords = cursor.getNumRecords();

            // Build result
            PaginatedResult result = new PaginatedResult();
            result.records = issues;
            result.currentPosition = position;
            result.totalRecords = totalRecords;
            result.pageSize = pageSize;
            result.hasNextPage = (position + pageSize) < totalRecords;
            result.hasPreviousPage = position > 0;
            result.currentPage = (position / pageSize) + 1;
            result.totalPages = (Integer)Math.ceil((Decimal)totalRecords / pageSize);
            result.cursorState = String.valueOf(position);

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to fetch issues: ' + e.getMessage());
        }
    }

    /**
     * @description Get paginated list of duplicate records
     */
    @AuraEnabled(cacheable=false)
    public static PaginatedResult getDuplicateRecords(
        Integer pageSize,
        String cursorState,
        String direction
    ) {
        try {
            pageSize = pageSize != null ? pageSize : DEFAULT_PAGE_SIZE;

            String duplicateQuery = 'SELECT Id, Record_1_Id__c, Record_2_Id__c, ' +
                                   'Object_Type__c, Match_Score__c, Status__c, ' +
                                   'Job_Id__c, CreatedDate ' +
                                   'FROM Duplicate_Record__c ' +
                                   'WHERE Status__c != \'Merged\' ' +
                                   'ORDER BY Match_Score__c DESC, CreatedDate DESC';

            Database.Cursor cursor;
            Integer position = 0;

            if (String.isNotBlank(cursorState)) {
                cursor = (Database.Cursor)Cache.Session.get(CACHE_KEY_PREFIX + 'duplicates');
                position = Integer.valueOf(cursorState);

                if (direction == 'next') {
                    position += pageSize;
                } else if (direction == 'previous') {
                    position = Math.max(0, position - pageSize);
                }
            } else {
                cursor = Database.getCursor(duplicateQuery);
                Cache.Session.put(CACHE_KEY_PREFIX + 'duplicates', cursor);
            }

            List<Duplicate_Record__c> duplicates = cursor.fetch(position, pageSize);
            Integer totalRecords = cursor.getNumRecords();

            PaginatedResult result = new PaginatedResult();
            result.records = duplicates;
            result.currentPosition = position;
            result.totalRecords = totalRecords;
            result.pageSize = pageSize;
            result.hasNextPage = (position + pageSize) < totalRecords;
            result.hasPreviousPage = position > 0;
            result.currentPage = (position / pageSize) + 1;
            result.totalPages = (Integer)Math.ceil((Decimal)totalRecords / pageSize);
            result.cursorState = String.valueOf(position);

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to fetch duplicates: ' + e.getMessage());
        }
    }

    /**
     * @description Get job history with pagination
     */
    @AuraEnabled(cacheable=false)
    public static PaginatedResult getJobHistory(
        Integer pageSize,
        String cursorState,
        String direction
    ) {
        try {
            pageSize = pageSize != null ? pageSize : 20;

            String jobQuery = 'SELECT Id, Job_Id__c, Status__c, Processing_Mode__c, ' +
                             'Accounts_Processed__c, Contacts_Processed__c, ' +
                             'Opportunities_Processed__c, Cases_Processed__c, ' +
                             'Total_Accounts__c, Total_Contacts__c, ' +
                             'Total_Opportunities__c, Total_Cases__c, ' +
                             'Issues_Found__c, Duplicates_Found__c, ' +
                             'Average_Quality_Score__c, Execution_Count__c, ' +
                             'CreatedDate, Completion_Time__c, Error_Message__c ' +
                             'FROM Data_Quality_Job__c ' +
                             'ORDER BY CreatedDate DESC';

            Database.Cursor cursor;
            Integer position = 0;

            if (String.isNotBlank(cursorState)) {
                cursor = (Database.Cursor)Cache.Session.get(CACHE_KEY_PREFIX + 'jobs');
                position = Integer.valueOf(cursorState);

                if (direction == 'next') {
                    position += pageSize;
                } else if (direction == 'previous') {
                    position = Math.max(0, position - pageSize);
                }
            } else {
                cursor = Database.getCursor(jobQuery);
                Cache.Session.put(CACHE_KEY_PREFIX + 'jobs', cursor);
            }

            List<Data_Quality_Job__c> jobs = cursor.fetch(position, pageSize);
            Integer totalRecords = cursor.getNumRecords();

            PaginatedResult result = new PaginatedResult();
            result.records = jobs;
            result.currentPosition = position;
            result.totalRecords = totalRecords;
            result.pageSize = pageSize;
            result.hasNextPage = (position + pageSize) < totalRecords;
            result.hasPreviousPage = position > 0;
            result.currentPage = (position / pageSize) + 1;
            result.totalPages = (Integer)Math.ceil((Decimal)totalRecords / pageSize);
            result.cursorState = String.valueOf(position);

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to fetch job history: ' + e.getMessage());
        }
    }

    /**
     * @description Jump to a specific page number
     */
    @AuraEnabled(cacheable=false)
    public static PaginatedResult jumpToPage(
        String objectType,
        Integer pageNumber,
        Integer pageSize
    ) {
        try {
            String cacheKey = CACHE_KEY_PREFIX +
                (objectType == 'issues' ? 'issues' :
                 objectType == 'duplicates' ? 'duplicates' : 'jobs');

            Database.Cursor cursor = (Database.Cursor)Cache.Session.get(cacheKey);

            if (cursor == null) {
                throw new AuraHandledException('Cursor expired. Please refresh the page.');
            }

            Integer totalRecords = cursor.getNumRecords();
            Integer totalPages = (Integer)Math.ceil((Decimal)totalRecords / pageSize);

            // Validate page number
            pageNumber = Math.max(1, Math.min(pageNumber, totalPages));
            Integer position = (pageNumber - 1) * pageSize;

            List<SObject> records = cursor.fetch(position, pageSize);

            PaginatedResult result = new PaginatedResult();
            result.records = records;
            result.currentPosition = position;
            result.totalRecords = totalRecords;
            result.pageSize = pageSize;
            result.hasNextPage = (position + pageSize) < totalRecords;
            result.hasPreviousPage = position > 0;
            result.currentPage = pageNumber;
            result.totalPages = totalPages;
            result.cursorState = String.valueOf(position);

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to jump to page: ' + e.getMessage());
        }
    }

    /**
     * @description Get current job status for real-time monitoring
     */
    @AuraEnabled(cacheable=false)
    public static JobStatus getJobStatus(String jobId) {
        try {
            List<Data_Quality_Job__c> jobs = [
                SELECT Job_Id__c, Status__c, Processing_Mode__c,
                       Accounts_Processed__c, Contacts_Processed__c,
                       Opportunities_Processed__c, Cases_Processed__c,
                       Total_Accounts__c, Total_Contacts__c,
                       Total_Opportunities__c, Total_Cases__c,
                       Issues_Found__c, Duplicates_Found__c,
                       Average_Quality_Score__c, Execution_Count__c,
                       Last_Execution_Time__c, Error_Message__c
                FROM Data_Quality_Job__c
                WHERE Job_Id__c = :jobId
                LIMIT 1
            ];

            if (jobs.isEmpty()) {
                return null;
            }

            Data_Quality_Job__c job = jobs[0];

            JobStatus status = new JobStatus();
            status.jobId = job.Job_Id__c;
            status.status = job.Status__c;
            status.processingMode = job.Processing_Mode__c;

            status.accountsProcessed = Integer.valueOf(job.Accounts_Processed__c);
            status.totalAccounts = Integer.valueOf(job.Total_Accounts__c);
            status.contactsProcessed = Integer.valueOf(job.Contacts_Processed__c);
            status.totalContacts = Integer.valueOf(job.Total_Contacts__c);
            status.opportunitiesProcessed = Integer.valueOf(job.Opportunities_Processed__c);
            status.totalOpportunities = Integer.valueOf(job.Total_Opportunities__c);
            status.casesProcessed = Integer.valueOf(job.Cases_Processed__c);
            status.totalCases = Integer.valueOf(job.Total_Cases__c);

            status.issuesFound = Integer.valueOf(job.Issues_Found__c);
            status.duplicatesFound = Integer.valueOf(job.Duplicates_Found__c);
            status.averageQualityScore = job.Average_Quality_Score__c;
            status.executionCount = Integer.valueOf(job.Execution_Count__c);
            status.lastExecutionTime = job.Last_Execution_Time__c;
            status.errorMessage = job.Error_Message__c;

            // Calculate overall progress
            Integer totalProcessed = status.accountsProcessed + status.contactsProcessed +
                                    status.opportunitiesProcessed + status.casesProcessed;
            Integer totalRecords = status.totalAccounts + status.totalContacts +
                                  status.totalOpportunities + status.totalCases;

            status.overallProgressPercent = totalRecords > 0 ?
                (Decimal)totalProcessed / totalRecords * 100 : 0;

            return status;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to get job status: ' + e.getMessage());
        }
    }

    /**
     * @description Get dashboard statistics
     */
    @AuraEnabled(cacheable=true)
    public static DashboardStats getDashboardStats() {
        try {
            DashboardStats stats = new DashboardStats();

            // Count issues by severity
            List<AggregateResult> severityCounts = [
                SELECT Severity__c, COUNT(Id) cnt
                FROM Data_Quality_Issue__c
                WHERE Status__c != 'Resolved'
                GROUP BY Severity__c
            ];

            stats.criticalIssues = 0;
            stats.highIssues = 0;
            stats.mediumIssues = 0;
            stats.lowIssues = 0;

            for (AggregateResult ar : severityCounts) {
                String severity = (String)ar.get('Severity__c');
                Integer count = (Integer)ar.get('cnt');

                if (severity == 'Critical') stats.criticalIssues = count;
                else if (severity == 'High') stats.highIssues = count;
                else if (severity == 'Medium') stats.mediumIssues = count;
                else if (severity == 'Low') stats.lowIssues = count;
            }

            stats.totalIssues = stats.criticalIssues + stats.highIssues +
                               stats.mediumIssues + stats.lowIssues;

            // Count pending duplicates
            stats.pendingDuplicates = [
                SELECT COUNT()
                FROM Duplicate_Record__c
                WHERE Status__c != 'Merged'
            ];

            // Get recent job stats
            List<Data_Quality_Job__c> recentJobs = [
                SELECT Average_Quality_Score__c
                FROM Data_Quality_Job__c
                WHERE Status__c = 'Completed'
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];

            if (!recentJobs.isEmpty()) {
                Decimal scoreSum = 0;
                for (Data_Quality_Job__c job : recentJobs) {
                    scoreSum += job.Average_Quality_Score__c != null ?
                               job.Average_Quality_Score__c : 0;
                }
                stats.avgQualityScore = scoreSum / recentJobs.size();
            }

            // Count jobs by status
            List<AggregateResult> jobCounts = [
                SELECT Status__c, COUNT(Id) cnt
                FROM Data_Quality_Job__c
                GROUP BY Status__c
            ];

            stats.completedJobs = 0;
            stats.failedJobs = 0;
            stats.inProgressJobs = 0;

            for (AggregateResult ar : jobCounts) {
                String status = (String)ar.get('Status__c');
                Integer count = (Integer)ar.get('cnt');

                if (status == 'Completed') stats.completedJobs = count;
                else if (status == 'Error') stats.failedJobs = count;
                else if (status == 'In Progress') stats.inProgressJobs = count;
            }

            return stats;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to get dashboard stats: ' + e.getMessage());
        }
    }

    /**
     * @description Resolve a data quality issue
     */
    @AuraEnabled
    public static void resolveIssue(Id issueId, String resolution) {
        try {
            Data_Quality_Issue__c issue = new Data_Quality_Issue__c(
                Id = issueId,
                Status__c = 'Resolved',
                Resolution__c = resolution,
                Resolved_Date__c = Date.today()
            );
            update issue;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to resolve issue: ' + e.getMessage());
        }
    }

    /**
     * @description Mark duplicate as merged
     */
    @AuraEnabled
    public static void markDuplicateMerged(Id duplicateId) {
        try {
            Duplicate_Record__c duplicate = new Duplicate_Record__c(
                Id = duplicateId,
                Status__c = 'Merged',
                Merged_Date__c = Date.today()
            );
            update duplicate;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to mark duplicate: ' + e.getMessage());
        }
    }

    // ============================================
    // WRAPPER CLASSES
    // ============================================

    /**
     * @description Pagination result wrapper
     */
    public class PaginatedResult {
        @AuraEnabled public List<SObject> records;
        @AuraEnabled public Integer currentPosition;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Boolean hasNextPage;
        @AuraEnabled public Boolean hasPreviousPage;
        @AuraEnabled public Integer currentPage;
        @AuraEnabled public Integer totalPages;
        @AuraEnabled public String cursorState;
    }

    /**
     * @description Job status wrapper for real-time monitoring
     */
    public class JobStatus {
        @AuraEnabled public String jobId;
        @AuraEnabled public String status;
        @AuraEnabled public String processingMode;

        @AuraEnabled public Integer accountsProcessed;
        @AuraEnabled public Integer totalAccounts;
        @AuraEnabled public Integer contactsProcessed;
        @AuraEnabled public Integer totalContacts;
        @AuraEnabled public Integer opportunitiesProcessed;
        @AuraEnabled public Integer totalOpportunities;
        @AuraEnabled public Integer casesProcessed;
        @AuraEnabled public Integer totalCases;

        @AuraEnabled public Integer issuesFound;
        @AuraEnabled public Integer duplicatesFound;
        @AuraEnabled public Decimal averageQualityScore;
        @AuraEnabled public Integer executionCount;
        @AuraEnabled public Datetime lastExecutionTime;
        @AuraEnabled public String errorMessage;

        @AuraEnabled public Decimal overallProgressPercent;
    }

    /**
     * @description Dashboard statistics wrapper
     */
    public class DashboardStats {
        @AuraEnabled public Integer totalIssues;
        @AuraEnabled public Integer criticalIssues;
        @AuraEnabled public Integer highIssues;
        @AuraEnabled public Integer mediumIssues;
        @AuraEnabled public Integer lowIssues;
        @AuraEnabled public Integer pendingDuplicates;
        @AuraEnabled public Decimal avgQualityScore;
        @AuraEnabled public Integer completedJobs;
        @AuraEnabled public Integer failedJobs;
        @AuraEnabled public Integer inProgressJobs;
    }
}
