/**
 * @description       : 
 * @author            : Syed Kashan
 * @group             : 
 * @last modified on  : 06-05-2025
 * @last modified by  : Syed Kashan
**/
import { LightningElement,track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FORM_FACTOR from '@salesforce/client/formFactor';

export default class QuoteCmpOffline extends LightningElement {
      
    selectedAccountId = '';
    selectedAccountName = '';
    selectedLocationId = '';
    selectedLocationName = '';
    @track productsTable = [];

    get location_QueryFilters() {
        const filters = [];
    
        filters.push(`Id != null`);
        // if (this.someOtherField) {
        //     filters.push(`SomeField__c = '${this.someOtherField}'`);
        // }
    
        return filters.join(' AND ');
    }

    
    get isMobile() {
        return FORM_FACTOR === 'Small' ? true : false;
    }

    accountSelectionHandler(event) {
        let record = event.detail.record;
        this.selectedAccountId = record.Id;
        this.selectedAccountName = record.Name;
    }

    accountRemovedHandler() {
        this.selectedAccountId = '';
        this.selectedAccountName = '';
        this.selectedLocationId = '';
        this.selectedLocationName = '';
        this.productsTable = [];
    }

    locationSelectionHandler(event) {
        let record = event.detail.record;
        this.selectedLocationId = record.Id;
        this.selectedLocationName = record.Name;
    }

    locationRemovedHandler() {
        this.selectedLocationId = '';
        this.selectedLocationName = '';
    }

    getIndex() {
        return this.productsTable.length;
    }

    getNewProductObject() {
        return {
            rowNumber: this.getIndex(),
            productId: '',
            productName: '',
            quantity: 0,
            unitPrice: 0,
            description: ''
        };
    }

    handleAddRow() {
        const newRow = this.getNewProductObject();
        this.productsTable = [...this.productsTable, newRow];
    }

    handleProductSelection(event) {
        const rowNum = event.target.dataset.id;
        const index = this.productsTable.findIndex(p => p.rowNumber == rowNum);
        if (index !== -1) {
            const record = event.detail.record;
            this.productsTable[index].productId = record.Id;
            this.productsTable[index].productName = record.Name;
            this.productsTable[index].description = record.Description;
            this.productsTable[index].unitPrice = record.salesPrice;
        }
    }

    handleProductRemoved(event) {
        const rowNum = event.target.dataset.id;
        const index = this.productsTable.findIndex(p => p.rowNumber == rowNum);
        if (index !== -1) {
            this.productsTable[index].productId = '';
            this.productsTable[index].productName = '';
            this.productsTable[index].description = '';
            this.productsTable[index].unitPrice = 0;
            this.productsTable[index].quantity = 0;
        }
    }

    handleQuantityChange(event) {
        const rowNum = event.target.dataset.id;
        const index = this.productsTable.findIndex(p => p.rowNumber == rowNum);
        if (index !== -1) {
            this.productsTable[index].quantity = event.detail.value;
        }
    }

    handleDescriptionChange(event) {
        const rowNum = event.target.dataset.id;
        const index = this.productsTable.findIndex(p => p.rowNumber == rowNum);
        if (index !== -1) {
            this.productsTable[index].description = event.detail.value;
        }
    }

    handleDeleteRow(event) {
        const rowNum = event.target.dataset.id;
        this.productsTable = this.productsTable.filter(p => p.rowNumber != rowNum);
    }

    handleCancel() {
        const event = new CustomEvent('cancel');
        this.dispatchEvent(event);
    }    

    handleSave() {
        if (!this.selectedAccountId || !this.selectedLocationId) {
            this.showToast('Error','Account and Location are required.','error');
            return;
        }

        if (this.productsTable.length === 0) {
            this.showToast('Error','Please add at least one product.','error');
            return;
        }

        const noProductIdRow = this.productsTable.find(element => !element.productId);
        if (noProductIdRow) {
            this.showToast('Error', 'Product is required', 'error');
            return;
        }

        if(!this.isInputValid()){
            return
        }
        
        // TODO: Save this in local storage or cache queue
        this.insertQuoteInLocalStorage();
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }

    isInputValid(){
        let isValid = true;
        let inputFields = this.template.querySelectorAll('.validate');
        inputFields.forEach(inputField => {
            if(!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            } 
        });
        return isValid;
    }
    

    insertQuoteInLocalStorage(){
        
        const quoteId = 'offline_' + Date.now(); // unique offline ID

        const quotePayload = {
            id: quoteId,
            accountId: this.selectedAccountId,
            accountName: this.selectedAccountName,
            locationId: this.selectedLocationId,
            locationName: this.selectedLocationName,
            products: this.productsTable
        };

        // Fetch existing cached quotes
        let cachedQuotes = JSON.parse(localStorage.getItem('cachedOfflineQuotes')) || [];

        // Add new one
        cachedQuotes.push(quotePayload);
        localStorage.setItem('cachedOfflineQuotes', JSON.stringify(cachedQuotes));

        this.showToast('Success','Quote saved offline.','success');

        // Optional: reset view or navigate back
        this.dispatchEvent(new CustomEvent('cancel'));
    }
}