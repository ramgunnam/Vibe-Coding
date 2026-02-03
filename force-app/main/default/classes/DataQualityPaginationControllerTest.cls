/**
 * @description Test class for DataQualityPaginationController
 * Tests LWC controller methods for cursor-based pagination
 */
@isTest
private class DataQualityPaginationControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test job
        Data_Quality_Job__c job = new Data_Quality_Job__c(
            Job_Id__c = 'TEST-JOB-001',
            Status__c = 'Completed',
            Processing_Mode__c = 'FULL_SCAN',
            Accounts_Processed__c = 100,
            Contacts_Processed__c = 200,
            Opportunities_Processed__c = 50,
            Cases_Processed__c = 25,
            Total_Accounts__c = 100,
            Total_Contacts__c = 200,
            Total_Opportunities__c = 50,
            Total_Cases__c = 25,
            Issues_Found__c = 15,
            Duplicates_Found__c = 5,
            Average_Quality_Score__c = 85.5,
            Execution_Count__c = 3
        );
        insert job;

        // Create test issues
        List<Data_Quality_Issue__c> issues = new List<Data_Quality_Issue__c>();
        for (Integer i = 0; i < 100; i++) {
            issues.add(new Data_Quality_Issue__c(
                Record_Id__c = '001000000000' + String.valueOf(i).leftPad(3, '0'),
                Object_Type__c = 'Account',
                Issue_Type__c = Math.mod(i, 4) == 0 ? 'INCOMPLETE_ADDRESS' :
                               Math.mod(i, 4) == 1 ? 'MISSING_PHONE' :
                               Math.mod(i, 4) == 2 ? 'INVALID_EMAIL' : 'STALE_DATA',
                Description__c = 'Test issue ' + i,
                Severity__c = Math.mod(i, 4) == 0 ? 'Critical' :
                             Math.mod(i, 4) == 1 ? 'High' :
                             Math.mod(i, 4) == 2 ? 'Medium' : 'Low',
                Status__c = 'Open',
                Job_Id__c = 'TEST-JOB-001',
                Detected_Date__c = Date.today()
            ));
        }
        insert issues;

        // Create test duplicates
        List<Duplicate_Record__c> duplicates = new List<Duplicate_Record__c>();
        for (Integer i = 0; i < 50; i++) {
            duplicates.add(new Duplicate_Record__c(
                Record_1_Id__c = '001000000001' + String.valueOf(i).leftPad(3, '0'),
                Record_2_Id__c = '001000000002' + String.valueOf(i).leftPad(3, '0'),
                Object_Type__c = 'Account',
                Match_Score__c = 70 + Math.mod(i, 30),
                Status__c = 'Pending Review',
                Job_Id__c = 'TEST-JOB-001'
            ));
        }
        insert duplicates;
    }

    @isTest
    static void testStartDataQualityJob() {
        Test.startTest();

        String jobId = DataQualityPaginationController.startDataQualityJob('FULL_SCAN');

        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testStartDataQualityJobIncrementalMode() {
        Test.startTest();

        String jobId = DataQualityPaginationController.startDataQualityJob('INCREMENTAL');

        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testStartDataQualityJobComplianceMode() {
        Test.startTest();

        String jobId = DataQualityPaginationController.startDataQualityJob('COMPLIANCE_AUDIT');

        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testResumeDataQualityJob() {
        Test.startTest();

        String jobId = DataQualityPaginationController.resumeDataQualityJob('TEST-JOB-001');

        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testGetDataQualityIssuesFirstPage() {
        Test.startTest();

        DataQualityPaginationController.PaginatedResult result =
            DataQualityPaginationController.getDataQualityIssues(20, null, 'first');

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(20, result.pageSize);
        System.assertEquals(1, result.currentPage);
        System.assert(result.totalRecords >= 100);
        System.assertEquals(true, result.hasNextPage);
        System.assertEquals(false, result.hasPreviousPage);
    }

    @isTest
    static void testGetDataQualityIssuesNextPage() {
        // First get the first page
        DataQualityPaginationController.PaginatedResult firstPage =
            DataQualityPaginationController.getDataQualityIssues(20, null, 'first');

        Test.startTest();

        // Then get the next page
        DataQualityPaginationController.PaginatedResult result =
            DataQualityPaginationController.getDataQualityIssues(
                20,
                firstPage.cursorState,
                'next'
            );

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(2, result.currentPage);
        System.assertEquals(true, result.hasPreviousPage);
    }

    @isTest
    static void testGetDataQualityIssuesPreviousPage() {
        // First get pages to establish cursor state
        DataQualityPaginationController.PaginatedResult firstPage =
            DataQualityPaginationController.getDataQualityIssues(20, null, 'first');

        DataQualityPaginationController.PaginatedResult secondPage =
            DataQualityPaginationController.getDataQualityIssues(
                20,
                firstPage.cursorState,
                'next'
            );

        Test.startTest();

        // Go back to previous page
        DataQualityPaginationController.PaginatedResult result =
            DataQualityPaginationController.getDataQualityIssues(
                20,
                secondPage.cursorState,
                'previous'
            );

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(1, result.currentPage);
    }

    @isTest
    static void testGetDuplicateRecordsFirstPage() {
        Test.startTest();

        DataQualityPaginationController.PaginatedResult result =
            DataQualityPaginationController.getDuplicateRecords(20, null, 'first');

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(20, result.pageSize);
        System.assert(result.totalRecords >= 50);
    }

    @isTest
    static void testGetDuplicateRecordsNavigation() {
        DataQualityPaginationController.PaginatedResult firstPage =
            DataQualityPaginationController.getDuplicateRecords(20, null, 'first');

        Test.startTest();

        DataQualityPaginationController.PaginatedResult nextPage =
            DataQualityPaginationController.getDuplicateRecords(
                20,
                firstPage.cursorState,
                'next'
            );

        Test.stopTest();

        System.assertNotEquals(null, nextPage);
        System.assertEquals(2, nextPage.currentPage);
    }

    @isTest
    static void testGetJobHistoryFirstPage() {
        Test.startTest();

        DataQualityPaginationController.PaginatedResult result =
            DataQualityPaginationController.getJobHistory(10, null, 'first');

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.totalRecords >= 1);
    }

    @isTest
    static void testJumpToPage() {
        // First establish cursor
        DataQualityPaginationController.getDataQualityIssues(20, null, 'first');

        Test.startTest();

        DataQualityPaginationController.PaginatedResult result =
            DataQualityPaginationController.jumpToPage('issues', 3, 20);

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(3, result.currentPage);
    }

    @isTest
    static void testGetJobStatus() {
        Test.startTest();

        DataQualityPaginationController.JobStatus status =
            DataQualityPaginationController.getJobStatus('TEST-JOB-001');

        Test.stopTest();

        System.assertNotEquals(null, status);
        System.assertEquals('TEST-JOB-001', status.jobId);
        System.assertEquals('Completed', status.status);
        System.assertEquals('FULL_SCAN', status.processingMode);
        System.assertEquals(100, status.accountsProcessed);
        System.assertEquals(200, status.contactsProcessed);
        System.assertEquals(15, status.issuesFound);
        System.assertEquals(5, status.duplicatesFound);
    }

    @isTest
    static void testGetJobStatusNotFound() {
        Test.startTest();

        DataQualityPaginationController.JobStatus status =
            DataQualityPaginationController.getJobStatus('NON-EXISTENT-JOB');

        Test.stopTest();

        System.assertEquals(null, status);
    }

    @isTest
    static void testGetDashboardStats() {
        Test.startTest();

        DataQualityPaginationController.DashboardStats stats =
            DataQualityPaginationController.getDashboardStats();

        Test.stopTest();

        System.assertNotEquals(null, stats);
        System.assert(stats.totalIssues >= 100);
        System.assert(stats.criticalIssues >= 0);
        System.assert(stats.highIssues >= 0);
        System.assert(stats.mediumIssues >= 0);
        System.assert(stats.lowIssues >= 0);
        System.assert(stats.pendingDuplicates >= 50);
        System.assert(stats.completedJobs >= 1);
    }

    @isTest
    static void testResolveIssue() {
        Data_Quality_Issue__c issue = [
            SELECT Id
            FROM Data_Quality_Issue__c
            WHERE Status__c = 'Open'
            LIMIT 1
        ];

        Test.startTest();

        DataQualityPaginationController.resolveIssue(
            issue.Id,
            'Resolved during testing'
        );

        Test.stopTest();

        Data_Quality_Issue__c updatedIssue = [
            SELECT Status__c, Resolution__c, Resolved_Date__c
            FROM Data_Quality_Issue__c
            WHERE Id = :issue.Id
        ];

        System.assertEquals('Resolved', updatedIssue.Status__c);
        System.assertEquals('Resolved during testing', updatedIssue.Resolution__c);
        System.assertEquals(Date.today(), updatedIssue.Resolved_Date__c);
    }

    @isTest
    static void testMarkDuplicateMerged() {
        Duplicate_Record__c duplicate = [
            SELECT Id
            FROM Duplicate_Record__c
            WHERE Status__c = 'Pending Review'
            LIMIT 1
        ];

        Test.startTest();

        DataQualityPaginationController.markDuplicateMerged(duplicate.Id);

        Test.stopTest();

        Duplicate_Record__c updatedDuplicate = [
            SELECT Status__c, Merged_Date__c
            FROM Duplicate_Record__c
            WHERE Id = :duplicate.Id
        ];

        System.assertEquals('Merged', updatedDuplicate.Status__c);
        System.assertEquals(Date.today(), updatedDuplicate.Merged_Date__c);
    }

    @isTest
    static void testWrapperClasses() {
        // Test PaginatedResult
        DataQualityPaginationController.PaginatedResult paginatedResult =
            new DataQualityPaginationController.PaginatedResult();
        paginatedResult.currentPosition = 0;
        paginatedResult.totalRecords = 100;
        paginatedResult.pageSize = 20;
        paginatedResult.hasNextPage = true;
        paginatedResult.hasPreviousPage = false;
        paginatedResult.currentPage = 1;
        paginatedResult.totalPages = 5;

        System.assertEquals(0, paginatedResult.currentPosition);
        System.assertEquals(100, paginatedResult.totalRecords);
        System.assertEquals(5, paginatedResult.totalPages);

        // Test JobStatus
        DataQualityPaginationController.JobStatus jobStatus =
            new DataQualityPaginationController.JobStatus();
        jobStatus.jobId = 'TEST-123';
        jobStatus.status = 'In Progress';
        jobStatus.accountsProcessed = 50;
        jobStatus.totalAccounts = 100;
        jobStatus.overallProgressPercent = 50.0;

        System.assertEquals('TEST-123', jobStatus.jobId);
        System.assertEquals(50.0, jobStatus.overallProgressPercent);

        // Test DashboardStats
        DataQualityPaginationController.DashboardStats dashboardStats =
            new DataQualityPaginationController.DashboardStats();
        dashboardStats.totalIssues = 100;
        dashboardStats.criticalIssues = 10;
        dashboardStats.highIssues = 20;
        dashboardStats.mediumIssues = 30;
        dashboardStats.lowIssues = 40;
        dashboardStats.pendingDuplicates = 25;
        dashboardStats.avgQualityScore = 85.5;
        dashboardStats.completedJobs = 5;
        dashboardStats.failedJobs = 1;
        dashboardStats.inProgressJobs = 2;

        System.assertEquals(100, dashboardStats.totalIssues);
        System.assertEquals(10, dashboardStats.criticalIssues);
        System.assertEquals(85.5, dashboardStats.avgQualityScore);
    }

    @isTest
    static void testErrorHandling() {
        // Test invalid mode
        Boolean exceptionThrown = false;
        try {
            DataQualityPaginationController.startDataQualityJob('INVALID_MODE');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Should throw exception for invalid mode');
    }
}
