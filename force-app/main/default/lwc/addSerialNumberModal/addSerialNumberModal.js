import { LightningElement,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import AddSerial_anim from '@salesforce/resourceUrl/Serial_anim';
import AddSerial_still from '@salesforce/resourceUrl/Serial_still';

export default class AddSerialNumberModal extends LightningElement {

    
    iconAddSerial_anim=AddSerial_anim;
    iconAddSerial_still=AddSerial_still;

    serialNumbers = [];
    recordDetailId = '';
    rowNum_Id = '';

    @api 
    get rowdetail(){
        return;
    };
    set rowdetail(val){
        this.recordDetailId = val.Id;
        this.rowNum_Id = val.rowNum_Id != null ? val.rowNum_Id : '';
        this.serialNumbers = [];
        if (val.serialNumberList.length > 0) {
            this.serialNumbers = [...val.serialNumberList]; // Use the spread operator to copy the array
        } else {
            for (let i = 1; i <= val.newQuantity; i++) {
                let tempObj = {
                    recordId: val.Id,
                    serialNumber: ''
                };
                this.serialNumbers.push(tempObj);
            }
        }
    }

    handleSerialNumberChange(event) {
        const index = event.target.dataset.index;
        const newSerialNumber = event.target.value;

        // Update the serial number in the array
        this.serialNumbers = this.serialNumbers.map((serial, idx) => {
            if (idx == index) {
                return { ...serial, serialNumber: newSerialNumber };
            }
            return serial;
        });
    }

    handleClose() {
        // Dispatch close event to close the modal
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSave() {
        // Dispatch an event with the serial numbers when the user saves
        const serialNumbersEvent = new CustomEvent('saveserialnumbers', {
            detail: {  // Add colon here
                serialNumbers: this.serialNumbers,
                rowId: this.recordDetailId,
                rowNum_Id: this.rowNum_Id,
            }
        });
        this.dispatchEvent(serialNumbersEvent);
        this.showToast('Success', 'Serial Numbers Added', 'success');
    }
    
    get isSaveDisabled() {
        // Disable save if any serial number is empty
        return this.serialNumbers.some(serial => !serial.serialNumber);
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