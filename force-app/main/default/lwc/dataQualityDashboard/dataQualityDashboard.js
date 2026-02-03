/**
 * @description LWC Dashboard for Data Quality Monitoring with Apex Cursors
 *
 * This component demonstrates real-time monitoring of cursor-based processing:
 * - Platform Event subscription for live updates
 * - Cursor-based pagination for large datasets
 * - Interactive job management
 */
import { LightningElement, track, wire } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Apex methods
import startDataQualityJob from '@salesforce/apex/DataQualityPaginationController.startDataQualityJob';
import resumeDataQualityJob from '@salesforce/apex/DataQualityPaginationController.resumeDataQualityJob';
import getJobStatus from '@salesforce/apex/DataQualityPaginationController.getJobStatus';
import getDashboardStats from '@salesforce/apex/DataQualityPaginationController.getDashboardStats';
import getDataQualityIssues from '@salesforce/apex/DataQualityPaginationController.getDataQualityIssues';
import getDuplicateRecords from '@salesforce/apex/DataQualityPaginationController.getDuplicateRecords';
import getJobHistory from '@salesforce/apex/DataQualityPaginationController.getJobHistory';
import jumpToPage from '@salesforce/apex/DataQualityPaginationController.jumpToPage';
import resolveIssue from '@salesforce/apex/DataQualityPaginationController.resolveIssue';
import markDuplicateMerged from '@salesforce/apex/DataQualityPaginationController.markDuplicateMerged';

const PAGE_SIZE = 50;
const CHANNEL_NAME = '/event/Data_Quality_Progress__e';

export default class DataQualityDashboard extends LightningElement {
    // Dashboard stats
    @track stats = {
        criticalIssues: 0,
        highIssues: 0,
        mediumIssues: 0,
        lowIssues: 0,
        pendingDuplicates: 0,
        avgQualityScore: 0
    };

    // Active job tracking
    @track activeJob = null;
    @track activeJobId = null;
    @track isJobRunning = false;

    // Pagination state
    @track issuesResult = null;
    @track duplicatesResult = null;
    @track jobsResult = null;

    // Selected processing mode
    selectedMode = 'FULL_SCAN';

    // Platform Event subscription
    subscription = {};

    // Column definitions
    issueColumns = [
        { label: 'Issue #', fieldName: 'Name', type: 'text' },
        { label: 'Object', fieldName: 'Object_Type__c', type: 'text' },
        { label: 'Type', fieldName: 'Issue_Type__c', type: 'text' },
        { label: 'Severity', fieldName: 'Severity__c', type: 'text',
          cellAttributes: {
            class: { fieldName: 'severityClass' }
          }
        },
        { label: 'Description', fieldName: 'Description__c', type: 'text', wrapText: true },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'View Record', name: 'view' },
                    { label: 'Resolve', name: 'resolve' }
                ]
            }
        }
    ];

    duplicateColumns = [
        { label: 'Duplicate #', fieldName: 'Name', type: 'text' },
        { label: 'Object Type', fieldName: 'Object_Type__c', type: 'text' },
        { label: 'Record 1', fieldName: 'Record_1_Id__c', type: 'text' },
        { label: 'Record 2', fieldName: 'Record_2_Id__c', type: 'text' },
        { label: 'Match Score', fieldName: 'Match_Score__c', type: 'percent' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'Compare', name: 'compare' },
                    { label: 'Mark Merged', name: 'merge' }
                ]
            }
        }
    ];

    jobColumns = [
        { label: 'Job ID', fieldName: 'Job_Id__c', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { label: 'Mode', fieldName: 'Processing_Mode__c', type: 'text' },
        { label: 'Accounts', fieldName: 'Accounts_Processed__c', type: 'number' },
        { label: 'Contacts', fieldName: 'Contacts_Processed__c', type: 'number' },
        { label: 'Issues', fieldName: 'Issues_Found__c', type: 'number' },
        { label: 'Quality Score', fieldName: 'Average_Quality_Score__c', type: 'number',
          typeAttributes: { minimumFractionDigits: 2 }
        },
        { label: 'Created', fieldName: 'CreatedDate', type: 'date',
          typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
          }
        },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'View Details', name: 'view' },
                    { label: 'Resume', name: 'resume' }
                ]
            }
        }
    ];

    // Processing mode options
    processingModes = [
        { label: 'Full Scan - All Records', value: 'FULL_SCAN' },
        { label: 'Incremental - Last 7 Days', value: 'INCREMENTAL' },
        { label: 'High Priority First', value: 'HIGH_PRIORITY_FIRST' },
        { label: 'Compliance Audit', value: 'COMPLIANCE_AUDIT' },
        { label: 'Duplicate Detection', value: 'DUPLICATE_DETECTION' }
    ];

    // Lifecycle hooks
    connectedCallback() {
        this.loadDashboardStats();
        this.loadIssues();
        this.loadDuplicates();
        this.loadJobHistory();
        this.subscribeToPlatformEvent();
    }

    disconnectedCallback() {
        this.unsubscribeFromPlatformEvent();
    }

    // Computed properties
    get formattedQualityScore() {
        return this.stats.avgQualityScore ? this.stats.avgQualityScore.toFixed(1) : '0.0';
    }

    get overallProgressPercent() {
        if (!this.activeJob) return 0;
        const total = this.activeJob.totalAccounts + this.activeJob.totalContacts +
                     this.activeJob.totalOpportunities + this.activeJob.totalCases;
        const processed = this.activeJob.accountsProcessed + this.activeJob.contactsProcessed +
                         this.activeJob.opportunitiesProcessed + this.activeJob.casesProcessed;
        return total > 0 ? Math.round((processed / total) * 100) : 0;
    }

    get accountProgressPercent() {
        if (!this.activeJob || !this.activeJob.totalAccounts) return 0;
        return Math.round((this.activeJob.accountsProcessed / this.activeJob.totalAccounts) * 100);
    }

    get contactProgressPercent() {
        if (!this.activeJob || !this.activeJob.totalContacts) return 0;
        return Math.round((this.activeJob.contactsProcessed / this.activeJob.totalContacts) * 100);
    }

    get opportunityProgressPercent() {
        if (!this.activeJob || !this.activeJob.totalOpportunities) return 0;
        return Math.round((this.activeJob.opportunitiesProcessed / this.activeJob.totalOpportunities) * 100);
    }

    get caseProgressPercent() {
        if (!this.activeJob || !this.activeJob.totalCases) return 0;
        return Math.round((this.activeJob.casesProcessed / this.activeJob.totalCases) * 100);
    }

    get activeJobQualityScore() {
        return this.activeJob?.averageQualityScore?.toFixed(1) || '0.0';
    }

    // Pagination computed properties
    get disableIssuesPrevious() {
        return !this.issuesResult || !this.issuesResult.hasPreviousPage;
    }

    get disableIssuesNext() {
        return !this.issuesResult || !this.issuesResult.hasNextPage;
    }

    get disableDuplicatesPrevious() {
        return !this.duplicatesResult || !this.duplicatesResult.hasPreviousPage;
    }

    get disableDuplicatesNext() {
        return !this.duplicatesResult || !this.duplicatesResult.hasNextPage;
    }

    get disableJobsPrevious() {
        return !this.jobsResult || !this.jobsResult.hasPreviousPage;
    }

    get disableJobsNext() {
        return !this.jobsResult || !this.jobsResult.hasNextPage;
    }

    // Platform Event subscription
    subscribeToPlatformEvent() {
        const messageCallback = (response) => {
            this.handlePlatformEvent(response);
        };

        subscribe(CHANNEL_NAME, -1, messageCallback).then((response) => {
            this.subscription = response;
        });

        onError((error) => {
            console.error('Platform Event error:', error);
        });
    }

    unsubscribeFromPlatformEvent() {
        unsubscribe(this.subscription, (response) => {
            console.log('Unsubscribed from Platform Event');
        });
    }

    handlePlatformEvent(response) {
        const payload = response.data.payload;

        // Update active job if it matches
        if (this.activeJobId && payload.Job_Id__c === this.activeJobId) {
            this.activeJob = {
                jobId: payload.Job_Id__c,
                status: payload.Status__c,
                accountsProcessed: payload.Accounts_Processed__c || 0,
                totalAccounts: payload.Total_Accounts__c || 0,
                contactsProcessed: payload.Contacts_Processed__c || 0,
                totalContacts: payload.Total_Contacts__c || 0,
                opportunitiesProcessed: payload.Opportunities_Processed__c || 0,
                totalOpportunities: payload.Total_Opportunities__c || 0,
                casesProcessed: payload.Cases_Processed__c || 0,
                totalCases: payload.Total_Cases__c || 0,
                issuesFound: payload.Issues_Found__c || 0,
                duplicatesFound: payload.Duplicates_Found__c || 0,
                averageQualityScore: payload.Average_Quality_Score__c || 0,
                executionCount: this.activeJob?.executionCount + 1 || 1
            };

            // Check for completion
            if (payload.Status__c === 'Completed') {
                this.isJobRunning = false;
                this.showToast('Success', 'Data quality job completed successfully', 'success');
                this.loadDashboardStats();
                this.loadIssues();
                this.loadDuplicates();
                this.loadJobHistory();
            } else if (payload.Status__c === 'Error') {
                this.isJobRunning = false;
                this.showToast('Error', payload.Error_Message__c || 'Job failed', 'error');
            }
        }
    }

    // Data loading methods
    async loadDashboardStats() {
        try {
            this.stats = await getDashboardStats();
        } catch (error) {
            this.showToast('Error', 'Failed to load dashboard stats', 'error');
        }
    }

    async loadIssues(cursorState = null, direction = 'first') {
        try {
            this.issuesResult = await getDataQualityIssues({
                pageSize: PAGE_SIZE,
                cursorState: cursorState,
                direction: direction
            });

            // Add severity class for styling
            if (this.issuesResult && this.issuesResult.records) {
                this.issuesResult.records = this.issuesResult.records.map(record => ({
                    ...record,
                    severityClass: this.getSeverityClass(record.Severity__c)
                }));
            }
        } catch (error) {
            this.showToast('Error', 'Failed to load issues', 'error');
        }
    }

    async loadDuplicates(cursorState = null, direction = 'first') {
        try {
            this.duplicatesResult = await getDuplicateRecords({
                pageSize: PAGE_SIZE,
                cursorState: cursorState,
                direction: direction
            });
        } catch (error) {
            this.showToast('Error', 'Failed to load duplicates', 'error');
        }
    }

    async loadJobHistory(cursorState = null, direction = 'first') {
        try {
            this.jobsResult = await getJobHistory({
                pageSize: 20,
                cursorState: cursorState,
                direction: direction
            });
        } catch (error) {
            this.showToast('Error', 'Failed to load job history', 'error');
        }
    }

    // Event handlers
    handleModeChange(event) {
        this.selectedMode = event.detail.value;
    }

    async handleStartJob() {
        try {
            this.isJobRunning = true;
            const jobId = await startDataQualityJob({ mode: this.selectedMode });
            this.activeJobId = jobId;
            this.activeJob = {
                jobId: jobId,
                status: 'Starting',
                accountsProcessed: 0,
                totalAccounts: 0,
                contactsProcessed: 0,
                totalContacts: 0,
                opportunitiesProcessed: 0,
                totalOpportunities: 0,
                casesProcessed: 0,
                totalCases: 0,
                issuesFound: 0,
                duplicatesFound: 0,
                averageQualityScore: 0,
                executionCount: 0
            };
            this.showToast('Success', 'Data quality job started', 'success');
        } catch (error) {
            this.isJobRunning = false;
            this.showToast('Error', error.body?.message || 'Failed to start job', 'error');
        }
    }

    // Pagination handlers - Issues
    handleIssuesPrevious() {
        this.loadIssues(this.issuesResult.cursorState, 'previous');
    }

    handleIssuesNext() {
        this.loadIssues(this.issuesResult.cursorState, 'next');
    }

    async handleIssuesPageJump(event) {
        const pageNumber = parseInt(event.target.value, 10);
        if (pageNumber >= 1 && pageNumber <= this.issuesResult.totalPages) {
            try {
                this.issuesResult = await jumpToPage({
                    objectType: 'issues',
                    pageNumber: pageNumber,
                    pageSize: PAGE_SIZE
                });
            } catch (error) {
                this.showToast('Error', 'Failed to jump to page', 'error');
            }
        }
    }

    // Pagination handlers - Duplicates
    handleDuplicatesPrevious() {
        this.loadDuplicates(this.duplicatesResult.cursorState, 'previous');
    }

    handleDuplicatesNext() {
        this.loadDuplicates(this.duplicatesResult.cursorState, 'next');
    }

    async handleDuplicatesPageJump(event) {
        const pageNumber = parseInt(event.target.value, 10);
        if (pageNumber >= 1 && pageNumber <= this.duplicatesResult.totalPages) {
            try {
                this.duplicatesResult = await jumpToPage({
                    objectType: 'duplicates',
                    pageNumber: pageNumber,
                    pageSize: PAGE_SIZE
                });
            } catch (error) {
                this.showToast('Error', 'Failed to jump to page', 'error');
            }
        }
    }

    // Pagination handlers - Jobs
    handleJobsPrevious() {
        this.loadJobHistory(this.jobsResult.cursorState, 'previous');
    }

    handleJobsNext() {
        this.loadJobHistory(this.jobsResult.cursorState, 'next');
    }

    // Row action handlers
    handleIssueRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        switch (action.name) {
            case 'view':
                this.navigateToRecord(row.Record_Id__c);
                break;
            case 'resolve':
                this.resolveIssue(row.Id);
                break;
        }
    }

    handleDuplicateRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        switch (action.name) {
            case 'compare':
                // Open comparison view
                break;
            case 'merge':
                this.markAsMerged(row.Id);
                break;
        }
    }

    async handleJobRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        switch (action.name) {
            case 'view':
                // Show job details modal
                break;
            case 'resume':
                await this.resumeJob(row.Job_Id__c);
                break;
        }
    }

    async resolveIssue(issueId) {
        try {
            await resolveIssue({ issueId: issueId, resolution: 'Resolved via dashboard' });
            this.showToast('Success', 'Issue resolved', 'success');
            this.loadIssues();
            this.loadDashboardStats();
        } catch (error) {
            this.showToast('Error', 'Failed to resolve issue', 'error');
        }
    }

    async markAsMerged(duplicateId) {
        try {
            await markDuplicateMerged({ duplicateId: duplicateId });
            this.showToast('Success', 'Marked as merged', 'success');
            this.loadDuplicates();
            this.loadDashboardStats();
        } catch (error) {
            this.showToast('Error', 'Failed to mark as merged', 'error');
        }
    }

    async resumeJob(jobId) {
        try {
            this.isJobRunning = true;
            this.activeJobId = jobId;
            await resumeDataQualityJob({ jobId: jobId });
            this.showToast('Success', 'Job resumed', 'success');
        } catch (error) {
            this.isJobRunning = false;
            this.showToast('Error', 'Failed to resume job', 'error');
        }
    }

    navigateToRecord(recordId) {
        // Navigate to record detail page
        window.open('/' + recordId, '_blank');
    }

    getSeverityClass(severity) {
        switch (severity) {
            case 'Critical':
                return 'slds-text-color_error';
            case 'High':
                return 'slds-text-color_error';
            case 'Medium':
                return 'slds-text-color_weak';
            default:
                return '';
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}
