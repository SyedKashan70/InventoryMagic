import { LightningElement, track } from 'lwc';
import getWarehouseExist from '@salesforce/apex/WarehouseController.getWarehouseExist';

export default class CreateNewWarehouseLWC extends LightningElement {
    @track warehouseFound = true; // To display the message
    warehouseFields = ['Name','IMagic__Warehouse_Manager__c','IMagic__Description__c','IMagic__Capacity__c'];

    // Called when the component is inserted into the DOM
    connectedCallback() {
        this.checkWarehouse();
    }

    // Call the Apex method
    checkWarehouse() {
        getWarehouseExist()
            .then((result) => {
                if (result) {
                    this.warehouseFound = true;
                } else {
                    this.warehouseFound = false;
                }
            })
            .catch((error) => {
                this.message = 'Error: ' + error.body.message;
            });
    }
}