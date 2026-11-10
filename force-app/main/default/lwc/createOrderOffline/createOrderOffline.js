/**
 * @description       : 
 * @author            : Syed Kashan
 * @group             : 
 * @last modified on  : 06-05-2025
 * @last modified by  : Syed Kashan
**/
import { LightningElement ,track} from 'lwc';
import FORM_FACTOR from '@salesforce/client/formFactor';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CreateOrderOffline extends LightningElement {
    
    selectedAccountId = '';
    selectedAccountName = '';
    selectedWarehouseId = '';
    selectedWarehouseName = '';
    selectedWarehouseManagerEmail = '';
    selectedLocationId = '';
    selectedLocationName = '';
    orderStartDate;
    @track productsTable = [];

    get location_QueryFilters() {
        const filters = [];
    
        if (this.selectedWarehouseId) {
            filters.push(`IMagic__Warehouse__c = '${this.selectedWarehouseId}'`);
        }
    
        return filters.join(' AND ');
    }

    
    get isMobile() {
        return FORM_FACTOR === 'Small' ? true : false;
    }

    
    getIndex() {
        return this.productsTable.length;
    }

    getNewObject() {
        return {
          rowNumber: this.getIndex(),
          productId: '',
          productName: '',
          lineDescription: '',
          quantity: 0,
          cost: 0,
          get totalPrice(){
            return this.quantity * this.cost;
          }
        };
    }

    handleAddRow() {
        const newRow = this.getNewObject();
        this.productsTable = [...this.productsTable, newRow];
    }
    
    
    accountSelectionHandler(event) {
        let record = event.detail.record;
        this.selectedAccountId = record.Id;
        this.selectedAccountName = record.Name;
    }

    accountRemovedHandler() {
        this.selectedAccountId = '';
        this.selectedAccountName = '';
    }

    warehouseSelectionHandler(event) {
        let record = event.detail.record;
        this.selectedWarehouseId = record.Id;
        this.selectedWarehouseName = record.Name;
        this.selectedWarehouseManagerEmail = record.IMagic__Warehouse_Manager__r.Email;
    }

    warehouseRemovedHandler() {
        this.selectedWarehouseId = '';
        this.selectedWarehouseName = '';
        this.selectedWarehouseManagerEmail = '';
        this.selectedLocationId = '';
        this.selectedLocationName = '';
    }

    locationSelectionHandler(event) {
        let recordDetail = event.detail.record;
        if (!recordDetail || !recordDetail.Id) {
            this.showToast('Error', 'Invalid location selected.', 'error');
            return;
        }
        this.selectedLocationId = recordDetail.Id;
        this.selectedLocationName = recordDetail.Name;
    }

    locationRemovedHandler() {
        this.selectedLocationId = '';
        this.selectedLocationName = '';
    }

    handleStartDateChange(event) {
        this.orderStartDate = event.target.value;
    }

    handleProductSelection(event) {
        const rowNum = event.target.dataset.id;
        const index = this.productsTable.findIndex(p => p.rowNumber == rowNum);
        if (index !== -1) {
            const record = event.detail.record;
            this.productsTable[index].productId = record.Id;
            this.productsTable[index].productName = record.Name;
            this.productsTable[index].lineDescription = record.Description;
            this.productsTable[index].cost = record.salesPrice;
        }
    }

    handleProductRemoved(event) {
        const rowNum = event.target.dataset.id;
        const index = this.productsTable.findIndex(p => p.rowNumber == rowNum);
        if (index !== -1) {
            this.productsTable[index].productId = '';
            this.productsTable[index].productName = '';
            this.productsTable[index].lineDescription = '';
            this.productsTable[index].cost = 0;
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

    handleCostChange(event) {
        const rowNum = event.target.dataset.id;
        const index = this.productsTable.findIndex(p => p.rowNumber == rowNum);
        if (index !== -1) {
            this.productsTable[index].cost = event.detail.value;
        }
    }

    handleDescriptionChange(event) {
        const rowNum = event.target.dataset.id;
        const index = this.productsTable.findIndex(p => p.rowNumber == rowNum);
        if (index !== -1) {
            this.productsTable[index].lineDescription = event.detail.value;
        }
    }

    handleDeleteRow(event) {
        const rowNum = event.target.dataset.id;
        this.productsTable = this.productsTable.filter(p => p.rowNumber != rowNum);
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

    handleCancel() {
        const event = new CustomEvent('cancel');
        this.dispatchEvent(event);
    }   

    handleSave(){
        if (!this.selectedAccountId) {
            this.showToast('Error','Account is required.','error');
            return;
        }

        if (!this.orderStartDate) {
            this.showToast('Error','Order Start Date is Required.','error');
            return;
        }

        if (!this.selectedWarehouseId) {
            this.showToast('Error','Warehouse is required.','error');
            return;
        }

        if (!this.selectedLocationId) {
            this.showToast('Error','Stocking Location is required.','error');
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
        this.insertOrderInLocalStorage();

    }

    insertOrderInLocalStorage(){
        
        const orderId = 'offline_' + Date.now(); // unique offline ID

        const orderpayload = {
            id: orderId,
            orderStartDate: this.orderStartDate,
            accountId: this.selectedAccountId,
            accountName: this.selectedAccountName,
            warehouseId: this.selectedWarehouseId,
            warehouseName: this.selectedWarehouseName,
            warehouseManagerEmail: this.selectedWarehouseManagerEmail,
            stockingLocationId: this.selectedLocationId,
            stockingLocationName: this.selectedLocationName,
            products: this.productsTable
        };

        // Fetch existing cached quotes
        let cachedOrders = JSON.parse(localStorage.getItem('cachedOfflineOrders')) || [];

        // Add new one
        cachedOrders.push(orderpayload);
        localStorage.setItem('cachedOfflineOrders', JSON.stringify(cachedOrders));

        this.showToast('Success','Order saved offline.','success');

        // Optional: reset view or navigate back
        this.dispatchEvent(new CustomEvent('cancel'));
    }

}