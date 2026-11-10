import {
    LightningElement,
    api,
    track
} from "lwc";

export default class LwcLookupOffline extends LightningElement {
    @api selectedValue;
    @api selectedRecordId;
    @api lookupLabel;
    @api iconName = 'standard:account';
    @api lookupPlaceholder = 'Search...';
    @api cacheRecordsName = '';

    @track searchKey = '';
    @track recordsList = [];
    @track allCachedRecords = [];
    @track message = '';
    @track showOptions = false;

    _queryFilters = ''; // backing variable

    @api
    get queryFilters() {
        return this._queryFilters;
    }

    set queryFilters(value) {
        this._queryFilters = value;
        this.filterRecords(); // re-filter on update
    }

    connectedCallback() {
        this.loadFromCache();
    }

    handleKeyChange(event) {
        this.searchKey = event.target.value;
        this.filterRecords();
    }

    handleonfocus() {
        this.showOptions = true;
    }

    onLeave() {
        setTimeout(() => {
            this.showOptions = false;
        }, 300);
    }

    recordSelection(event) {
        let index = event.currentTarget.dataset.index;
        let record = this.recordsList[index];
        this.selectedRecordId = record.Id;
        this.selectedValue = record.Name;

        this.dispatchEvent(new CustomEvent('recordselection', {
            detail: {
                record: record
            }
        }));
    }

    removeRecordOnLookup() {
        this.selectedValue = null;
        this.selectedRecordId = null;
        this.searchKey = '';
        this.dispatchEvent(new CustomEvent('recordremoved'));   
    }

    loadFromCache() {
        try {
            const cached = localStorage.getItem(this.cacheRecordsName);
            if (cached) {
                const parsed = JSON.parse(cached);
                this.allCachedRecords = parsed.map((rec, index) => ({
                    ...rec,
                    RowIndex: index
                }));
                this.filterRecords();
            } else {
                this.message = 'No offline data available';
            }
        } catch (err) {
            console.error('Error parsing offline data:', err);
            this.message = 'Error loading offline data';
        }
    }
    
    filterRecords() {
        let filtered = [...this.allCachedRecords];
        const hasQueryFilter = this._queryFilters && this._queryFilters.trim() !== '';
        const hasSearchKey = this.searchKey && this.searchKey.trim() !== '';
        
        if (hasQueryFilter) {
            const conditions = this._queryFilters.split(/\s+AND\s+/i).map(cond => cond.trim());
            filtered = filtered.filter(record => {
                return conditions.every(condition => {
                    const match = condition.match(/^([\w.]+)\s*=\s*(.+)$/);
                    if (!match) return true;
    
                    const [_, field, rawExpected] = match;
                    const path = field.split('.');
                    let expectedValue = rawExpected.replace(/^['"`]|['"`]$/g, '');
    
                    if (expectedValue.toLowerCase() === 'true') expectedValue = true;
                    else if (expectedValue.toLowerCase() === 'false') expectedValue = false;
                    else if (!isNaN(expectedValue)) expectedValue = Number(expectedValue);
    
                    let actualValue = record;
                    for (const part of path) {
                        actualValue = actualValue?.[part];
                    }
    
                    return actualValue === expectedValue;
                });
            });
        }
    
        if (hasSearchKey) {
            const keyword = this.searchKey.toLowerCase();
            filtered = filtered.filter(rec => rec.Name?.toLowerCase().includes(keyword));
        }
    
        // 🔧 Reassign RowIndex based on *filtered* array
        this.recordsList = filtered.map((rec, index) => ({
            ...rec,
            RowIndex: index
        }));
    
        this.message = this.recordsList.length === 0 ? 'No Records Found' : '';
    }
    
}