/**
 * @description       : 
 * @author            : Syed Kashan
 * @group             : 
 * @last modified on  : 06-05-2025
 * @last modified by  : Syed Kashan
**/
import { LightningElement,api,track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import AddSerial_anim from '@salesforce/resourceUrl/Serial_anim';
import AddSerial_still from '@salesforce/resourceUrl/Serial_still';

export default class AddSerialModalOffline extends LightningElement {

    iconAddSerial_anim=AddSerial_anim;
    iconAddSerial_still=AddSerial_still;

    
    serialList = [];
    invId;
    @track selectedInvDetailIds = [];

    get inventory_QueryFilters() {
        const filters = [];
    
        // Ensure that invId exists before adding it to the filter
        if (this.invId) {
            filters.push(`inventoryId = '${this.invId}'`);
        }
    
        // Ensure selectedInvDetailIds is not empty before adding it to the filter
        if (this.selectedInvDetailIds.length > 0) {
            filters.push(`Id NOT IN ('${this.selectedInvDetailIds.join("','")}')`);
        }

        filters.push(`isOrdered = FALSE`);
    

    
        return filters.join(' AND ');
    }
    
    

    @api 
    get serialRecord(){
        return;
    };
    set serialRecord(val){
        this.serialList = [];
        this.invId = val.invId;
        if (val.serialList.length > 0) {
            val.serialList.forEach(element => {
                let tempObj = this.getNewObject();
                tempObj.Id = element.Id;
                tempObj.Name = element.Name;
                this.serialList.push(tempObj);
                this.selectedInvDetailIds.push(element.Id);
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
            Id: '',
            Name: '',
            inventoryId: ''
        };
    }

    inventoryDetailSelectionHandler(event) {
        let rowNum = event.target.dataset.id;
        let recordDetail = event.detail.record;
        let tempArray = [...this.serialList];
        if (rowNum && recordDetail) {
            tempArray[rowNum].Id = recordDetail.Id;
            tempArray[rowNum].Name = recordDetail.Name;
            tempArray[rowNum].inventoryId = recordDetail.inventoryId;
            tempArray[rowNum].isOrdered = true;
            this.selectedInvDetailIds.push(recordDetail.Id);
            this.serialList = tempArray;
        }
    }

    inventoryDetailRemovedHandler(event) {
        let rowNum = event.target.dataset.id;
        let tempArray = [...this.serialList];
        if (rowNum) {
            const index = this.selectedInvDetailIds.indexOf(tempArray[rowNum].Id);
            if (index > -1) {
                this.selectedInvDetailIds.splice(index, 1);
            }
            tempArray[rowNum].Id = '';
            tempArray[rowNum].Name = '';
            tempArray[rowNum].inventoryId = '';
            tempArray[rowNum].isOrdered = false;
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
                invId: this.invId
            }
        });
        this.dispatchEvent(serialsEvent);
        this.showToast('Success', 'Serial Numbers Selected', 'success');
    }

    get isSaveDisabled() {
        // Check if any serial number has an empty Id or if there are duplicates
        const hasEmptyId = this.serialList.some(serial => !serial.Id);
        
        // Check for duplicates in serial Ids
        const idSet = new Set();
        const hasDuplicateIds = this.serialList.some(serial => {
            if (idSet.has(serial.Id)) {
                return true; // Duplicate found
            }
            idSet.add(serial.Id);
            return false;
        });
    
        // Save should be disabled if any serial has an empty Id or if there are duplicates
        return hasEmptyId || hasDuplicateIds;
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