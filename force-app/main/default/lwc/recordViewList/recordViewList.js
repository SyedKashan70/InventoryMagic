/**
 * @description       : 
 * @author            : Syed Kashan
 * @group             : 
 * @last modified on  : 05-05-2025
 * @last modified by  : Syed Kashan
**/
import { LightningElement, api, track } from 'lwc';

export default class RecordViewList extends LightningElement {
    @api recordList = [];
    @api objName = '';

    @track searchTerm = '';
    @track selectedRecord = null;
    @track isModalOpen = false;

    // Filter records by Name field
    get filterRecordList() {
        if (!this.searchTerm) return this.recordList;

        const term = this.searchTerm.toLowerCase();
        return this.recordList.filter(record =>
            (record.Name || '').toLowerCase().includes(term)
        );
    }

    // Handle search input
    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    // Handle back button
    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    // Handle list item click
    handleRecordClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this.selectedRecord = this.recordList.find(rec => rec.Id === recordId);
        this.isModalOpen = true;
    }

    // Close modal
    closeModal() {
        this.isModalOpen = false;
        this.selectedRecord = null;
    }

    // Convert selected record to key/value array
    get recordEntries() {
        if (!this.selectedRecord) return [];

        return Object.entries(this.selectedRecord)
            .filter(([key, _]) => key !== 'attributes') // Optional: filter unwanted fields
            .map(([key, value]) => ({
                key,
                value: value === null || value === undefined ? '' : value
            }));
    }
}
