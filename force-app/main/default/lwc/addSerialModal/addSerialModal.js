import { LightningElement,api,track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import AddSerial_anim from '@salesforce/resourceUrl/Serial_anim';
import AddSerial_still from '@salesforce/resourceUrl/Serial_still';

export default class AddSerialModal extends LightningElement {

    iconAddSerial_anim=AddSerial_anim;
    iconAddSerial_still=AddSerial_still;

    
    serialList = [];
    sourceInvId;
    rowNum_OrderNum;
    orderItemId;
    queryFilters;
    @track selectedInvDetailIds = [];

    inventoryDetail_QueryFields = ' ';
    inventoryDetail_OrderBy = ' IMagic__Serial_Number__c ASC';
    inventoryDetail_RecordLimit = 100;
    get inventoryDetail_QueryFilters() {
        let filter = '';
        // Ensure that sourceInvId exists before adding it to the filter
        if (this.sourceInvId) {
            filter = `IMagic__Inventory__c = '${this.sourceInvId}' AND Id NOT IN ('${this.selectedInvDetailIds.join("','")}') `;
        }
        // Append queryFilters only if it exists and is a valid string
        if (this.queryFilters && typeof this.queryFilters === 'string') {
            filter += this.queryFilters;
        }
        return filter;
    }
    

    // get inventoryDetail_QueryFilters(){
    //     if (this.sourceInvId) {
    //         return `IMagic__Inventory__c = '${this.sourceInvId}' AND Id NOT IN ('${this.selectedInvDetailIds.join("','")}') AND IMagic__Quantity__c > 0 `;
    //     }
    //     return '';
    // }

    @api 
    get serialRecord(){
        return;
    };
    set serialRecord(val){
        this.serialList = [];
        this.sourceInvId = val.sourceInvId;
        this.rowNum_OrderNum = val.rowNum_OrderNum != null ? val.rowNum_OrderNum : '';
        this.orderItemId = val.orderItemId != null ? val.orderItemId : '';
        this.queryFilters = val.queryFilters;
        if (val.serialList.length > 0) {
            // this.serialList = [...val.serialList]; // Use the spread operator to copy the array
            val.serialList.forEach(element => {
                let tempObj = this.getNewObject();
                tempObj.invDetailId = element.invDetailId;
                tempObj.invDetailName = element.invDetailName;
                this.serialList.push(tempObj);
                this.selectedInvDetailIds.push(element.invDetailId);
            });
        } else {
            for (let i = 1; i <= val.numOfSerials; i++) {
                this.serialList.push(this.getNewObject());
            }
        }
    }

    getIndex() {
        return this.serialList.length;
    }

    getNewObject() {
        return {
            rowNumber: this.getIndex(),
            invDetailId: '',
            invDetailName: '',
        };
    }

    inventoryDetailSelectionHandler(event) {
        let rowNum = event.target.dataset.id;
        let recordDetail = event.detail.record;
        let tempArray = [...this.serialList];
        if (rowNum && recordDetail) {
            tempArray[rowNum].invDetailId = recordDetail.Id;
            tempArray[rowNum].invDetailName = recordDetail.Name;
            this.selectedInvDetailIds.push(recordDetail.Id);
            this.serialList = tempArray;
        }
    }

    inventoryDetailRemovedHandler(event) {
        let rowNum = event.target.dataset.id;
        let tempArray = [...this.serialList];
        if (rowNum) {
            const index = this.selectedInvDetailIds.indexOf(tempArray[rowNum].invDetailId);
            if (index > -1) {
                this.selectedInvDetailIds.splice(index, 1);
            }
            tempArray[rowNum].invDetailId = '';
            tempArray[rowNum].invDetailName = '';
            this.serialList = tempArray;
        }
    }

    handleClose() {
        // Dispatch close event to close the modal
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSave() {
        // Dispatch an event with the serial numbers when the user saves
        const serialsEvent = new CustomEvent('saveserials', {
            detail: {  // Add colon here
                serialList: this.serialList,
                sourceInvId: this.sourceInvId,
                rowNum_OrderNum: this.rowNum_OrderNum,
                orderItemId: this.orderItemId
            }
        });
        this.dispatchEvent(serialsEvent);
        this.showToast('Success', 'Serial Numbers Selected', 'success');
    }

    get isSaveDisabled() {
        // Disable save if any serial number is empty
        return this.serialList.some(serial => !serial.invDetailId);
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
}