import { LightningElement, wire, track } from 'lwc';
import getMainWarehouseStockingLocation from '@salesforce/apex/StockAdjustmentController.getMainWarehouseStockingLocation';
import createStockAdjustment_Line from '@salesforce/apex/StockAdjustmentController.createStockAdjustment_Line';
import { getObjectInfo, getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import STOCK_ADJUSTMENT_LINE from '@salesforce/schema/Stock_Adjustment_Line__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import SA_still from '@salesforce/resourceUrl/SA_still';
import SA_anim from '@salesforce/resourceUrl/SA_anim';
import PO_bgImage from '@salesforce/resourceUrl/PO_bgImage';

export default class StockAdjustment extends LightningElement {
    get backgroundStyle() {
        return `max-height:calc(100vh - 150px);overflow: auto; height:auto;padding: 10px; border:1px solid grey;background-repeat: repeat;background-image:url(${PO_bgImage});`;
    }
    iconSA_anim=SA_anim;
    iconSA_still=SA_still;

    mainStockingLocation;
    @track stockAdjustmentLine = [];
    @track actionPicklistOptions = [];
    @track adjustmentTypePicklistOptions = [];
    showSerialModal = false;
    showSerialNumberModal = false;
    serialRecord;
    @track selectedProductIds = [];
    isLoading = false;

    sourceStockingLocationId = '';
    sourceStockingLocationName = '';
    sourceStockingLocation_QueryFields = '';
    sourceStockingLocation_OrderBy = ' Name ASC';
    sourceStockingLocation_RecordLimit = 100;
    get sourceStockingLocation_QueryFilters(){
        let filter = ' ';
        if(this.mainStockingLocation.IMagic__Warehouse__c){
            filter += ' IMagic__Warehouse__c  = \'' + this.mainStockingLocation.IMagic__Warehouse__c + '\'';
        }
        return filter;
    }

    product_QueryFields = ' RecordTypeId,RecordType.Name ';
    product_OrderBy = ' Name  ASC';
    product_RecordLimit = 100;
    get product_QueryFilters(){
        let filter = ' ';
        if(this.mainStockingLocation.IMagic__Warehouse__c){
            // filter += ' IMagic__Warehouse__c  = \'' + this.mainStockingLocation.IMagic__Warehouse__c + '\'';
            filter = `IMagic__Warehouse__c = '${this.mainStockingLocation.IMagic__Warehouse__c}' AND Id NOT IN ('${this.selectedProductIds.join("','")}') `;
        }
        return filter;
    }

    inventory_QueryFields = ' IMagic__Quantity_on_Hand__c,IMagic__Product__c,IMagic__Stocking_Location__c ';
    inventory_OrderBy = ' Name  ASC';
    inventory_RecordLimit = 100;

    getIndex = () => {
        return this.stockAdjustmentLine.length
    }

    getNewObject() {
        return {
            rowNumber: this.getIndex(),
            productId: '',
            productName: '',
            stockingLocationId:'',
            isSerialControlProduct: false,
            inventoryId: '',
            inventoryName: '',
            QuantityOnHand: 0,
            newQuantity: 0,
            action: '',
            AdjustmenType: '',
            adjustmentReason: '',
            serialList:[],
            serialNumberList:[],
            filteredAdjustmentTypePicklistOptions: [],
            get showSerialModalIcon(){
                return this.isSerialControlProduct == true && this.action == 'Minus' && (this.newQuantity > 0 && this.newQuantity <= this.QuantityOnHand);
            },
            get showSerialNumberIcon(){
                return this.isSerialControlProduct == true && this.action == 'Add' && this.newQuantity > 0;
            },
            get inventory_QueryFilters(){
                let filter = ' ';
                if(this.productId){
                    filter += ' IMagic__Product__c  = \'' + this.productId + '\' AND ';
                }
                if(this.stockingLocationId){
                    filter += ' IMagic__Stocking_Location__c  = \'' + this.stockingLocationId + '\'';
                }
                return filter;
            },
            get disableInventory(){
                return this.productId ? false : true;
            },
            get isMinusAction(){
                return this.action != 'Add' ? true : false;
            }
        };
    }

    
    @wire(getMainWarehouseStockingLocation)
    wiredStockingLocation({ error, data }) {
        if (data) {
            this.mainStockingLocation = data;
            this.sourceStockingLocationId = data.Id;
            this.sourceStockingLocationName = data.Name;
        } else if (error) {
            console.error('Error:', error);
        }
    }

    @wire(getObjectInfo, { objectApiName: 'IMagic__Stock_Adjustment_Line__c'})
    objectInfo;

    @wire(getPicklistValuesByRecordType, { objectApiName: 'IMagic__Stock_Adjustment_Line__c', recordTypeId: '$objectInfo.data.defaultRecordTypeId' })
    picklistValuesHandler({ error, data }) {
        if (data) {
            const actionOptions = data.picklistFieldValues.IMagic__Action__c;
            const adjustmentTypeOptions = data.picklistFieldValues.IMagic__AdjustmentType__c;

            // Store action picklist values
            this.actionPicklistOptions = actionOptions.values;

            // Map controlling values to dependent picklist options
            const dependentOptions = {};
            for (const [key, index] of Object.entries(adjustmentTypeOptions.controllerValues)) {
                dependentOptions[key] = adjustmentTypeOptions.values
                    .filter(option => option.validFor.includes(index))
                    .map(option => ({ label: option.label, value: option.value }));
            }

            this.adjustmentTypePicklistOptions = dependentOptions;
        } else if (error) {
            console.error(error);
        }
    }

    sourceStockingLocationSelectionHandler(event){
        let recordDetail = event.detail.record;
        this.sourceStockingLocationId = recordDetail.Id;
        this.sourceStockingLocationName = recordDetail.Name;
    }

    sourceStockingLocationRemovedHandler(){
        this.sourceStockingLocationId = '';
        this.sourceStockingLocationName = '';
        this.stockAdjustmentLine = [];
    }

    productSelectionHandler(event){
        let recordDetail = event.detail.record;
        let tempRowNumber = event.target.dataset.id; 
        const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == tempRowNumber);
        if(index != -1){
            this.stockAdjustmentLine[index].productId = recordDetail.Id;
            this.stockAdjustmentLine[index].productName = recordDetail.Name;
            this.selectedProductIds.push(recordDetail.Id);
            if(recordDetail.recordDetail.RecordType){
                this.stockAdjustmentLine[index].isSerialControlProduct = recordDetail.recordDetail.RecordType.Name == 'Serial Control' ? true : false;
            }
        }
    }

    productRemovedHandler(event){
        let tempRowNumber = event.target.dataset.id; 
        const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == tempRowNumber);
        if(index != -1){
            const selectedProductIdsIndex = this.selectedProductIds.indexOf(this.stockAdjustmentLine[index].productId);
            if (selectedProductIdsIndex > -1) {
                this.selectedProductIds.splice(selectedProductIdsIndex, 1);
            }
            this.stockAdjustmentLine[index].productId = '';
            this.stockAdjustmentLine[index].productName = '';
            this.stockAdjustmentLine[index].isSerialControlProduct = false;
            this.stockAdjustmentLine[index].inventoryId = '';
            this.stockAdjustmentLine[index].inventoryName = '';
            this.stockAdjustmentLine[index].QuantityOnHand = 0;
            this.stockAdjustmentLine[index].action = '';
            this.stockAdjustmentLine[index].AdjustmenType = '';
            this.stockAdjustmentLine[index].newQuantity = 0;
            this.stockAdjustmentLine[index].adjustmentReason = '';
        }
    }

    inventorySelectionHandler(event){
        let recordDetail = event.detail.record;
        let tempRowNumber = event.target.dataset.id; 
        const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == tempRowNumber);
        if(index != -1){
            this.stockAdjustmentLine[index].inventoryId = recordDetail.Id;
            this.stockAdjustmentLine[index].inventoryName = recordDetail.Name;
            this.stockAdjustmentLine[index].QuantityOnHand = recordDetail.IMagic__Quantity_on_Hand__c ? recordDetail.IMagic__Quantity_on_Hand__c : 0;
        }
    }

    inventoryRemovedHandler(event){
        let tempRowNumber = event.target.dataset.id; 
        const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == tempRowNumber);
        if(index != -1){
            this.stockAdjustmentLine[index].inventoryId = '';
            this.stockAdjustmentLine[index].inventoryName = '';
            this.stockAdjustmentLine[index].QuantityOnHand = 0;
            this.stockAdjustmentLine[index].action = '';
            this.stockAdjustmentLine[index].AdjustmenType = '';
            this.stockAdjustmentLine[index].newQuantity = 0;
            this.stockAdjustmentLine[index].adjustmentReason = '';
        }
    }

    handleActionChange(event) {
        let tempRowNumber = event.target.dataset.id; 
        const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == tempRowNumber);
        if(index != -1){
            const action = event.target.value;
            this.stockAdjustmentLine[index].action = action;
            this.stockAdjustmentLine[index].AdjustmenType = '';
            this.stockAdjustmentLine[index].filteredAdjustmentTypePicklistOptions =
                this.adjustmentTypePicklistOptions[action] || [];
        }
    }

    handleAdjustmentTypeChange(event){
        let tempRowNumber = event.target.dataset.id; 
        const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == tempRowNumber);
        if(index != -1){
            this.stockAdjustmentLine[index].AdjustmenType = event.target.value;
        }
    }

    handletransferQtyChange(event){
        let tempRowNumber = event.target.dataset.id; 
        const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == tempRowNumber);
        if(index != -1){
            this.stockAdjustmentLine[index].newQuantity = event.detail.value;
            this.template.querySelector('lightning-input[data-name="width').classList.add('btn-width');
        }
    }

    handleAdjustmentReasonChange(event){
        let tempRowNumber = event.target.dataset.id; 
        const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == tempRowNumber);
        if(index != -1){
            this.stockAdjustmentLine[index].adjustmentReason = event.detail.value;
        }
    }

    handleDeleteRow(event){
        let tempRowNumber = event.target.dataset.id; 
        const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == tempRowNumber);
        if (index !== -1) {
            this.stockAdjustmentLine = [
                ...this.stockAdjustmentLine.slice(0, index),
                ...this.stockAdjustmentLine.slice(index + 1)
            ];
        }
    }

    handleAddSerialClick(event){
       let tempRowNumber = event.target.dataset.id; 
       const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == tempRowNumber);
       if(index != -1){     
            let tempSerialRec = {
                numOfSerials: this.stockAdjustmentLine[index].newQuantity,
                serialList: this.stockAdjustmentLine[index].serialList,
                sourceInvId: this.stockAdjustmentLine[index].inventoryId,
                rowNum_OrderNum: tempRowNumber,
                orderItemId: null,
                queryFilters: ` AND Quantity__c > 0  `
            }
            this.serialRecord = tempSerialRec;
            this.showSerialModal = true;
            
       }
    }

    handleSerialNumberModalClick(event){
        let tempRowNumber = event.target.dataset.id; 
        const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == tempRowNumber);
        let tempSerialRec = {
            Id: this.stockAdjustmentLine[index].inventoryId,
            newQuantity: this.stockAdjustmentLine[index].newQuantity,
            serialNumberList: this.stockAdjustmentLine[index].serialNumberList,
            rowNum_Id: tempRowNumber
        }
        this.serialRecord = tempSerialRec;
        this.showSerialNumberModal = !this.showSerialNumberModal;
    }

    handleSaveSerials(event){
        const rowNum_OrderNum = event.detail.rowNum_OrderNum;
        const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == rowNum_OrderNum);
        if(index != -1){    
            this.stockAdjustmentLine[index].serialList = event.detail.serialList;
        }
        this.showSerialModal = false;
    }

    handleSaveSerialNumbers(event) {
        const rowNum_Id = event.detail.rowNum_Id;
        const index = this.stockAdjustmentLine.findIndex((element) => element.rowNumber == rowNum_Id);
        if (index !== -1) {
            this.stockAdjustmentLine[index].serialNumberList = event.detail.serialNumbers;
        } 
        this.showSerialNumberModal = false;
    }

    handleCloseModal() {
        this.showSerialNumberModal = false;
        this.showSerialModal = false;
    }

    handleAddRow(){
        let tempObj = this.getNewObject();
        tempObj.stockingLocationId = this.sourceStockingLocationId;
        let tempArray = this.stockAdjustmentLine;
        tempArray.push(tempObj);
        this.stockAdjustmentLine = []
        this.stockAdjustmentLine = tempArray;
    }

    handleSave(){
        if (this.stockAdjustmentLine.length == 0) {
            this.showToast('Error', 'Atleast add one Product', 'error');
            return;
        }
        const invalidProductRow = this.stockAdjustmentLine.find(element => {
            if (!element.productId) {
                return element;
            }
            return false;
        });
        if(invalidProductRow) {
            this.showToast('Error', `Product is Required.`, 'error');
            return;
        }


        const invalidDataRow = this.stockAdjustmentLine.find(element => {
            if (!element.productId || !element.inventoryId || !element.action || !element.AdjustmenType || element.newQuantity <= 0 || !element.adjustmentReason) {
                return element;
            }
            return false;
        });
        if(invalidDataRow) {
            this.showToast('Error', `${invalidDataRow.productName} have missing Data.`, 'error');
            return;
        }
        
        if(!this.isInputValid()){
          return
        }

        const invalidMinusRow = this.stockAdjustmentLine.find(element => {
        if (element.isSerialControlProduct && element.action == 'Minus' && element.newQuantity > 0) {
            return element.serialList.length === 0 ||
                    element.serialList.some(serial => !serial.invDetailId);
        }
        return false;  // Skip rows that aren't selected or aren't serial controlled
        });
        if (invalidMinusRow) {
            this.showToast('Error', `${invalidMinusRow.productName} has missing serials`, 'error');
            return;
        }

        const invalidAddRow = this.stockAdjustmentLine.find(element => {
        if (element.isSerialControlProduct && element.action == 'Add' && element.newQuantity > 0) {
            // Check if the serial number list is empty or has null values
            return element.serialNumberList.length === 0 ||
                    element.serialNumberList.some(serialNum => serialNum.serialNumber === null);
        }
        return false;  // Skip rows that aren't selected or aren't serial controlled
        });
        
        if (invalidAddRow) {
            this.showToast('Error', `${invalidAddRow.productName} has missing serial numbers`, 'error');
            return;
        }
        console.log(' this.stockAdjustmentLine. :: '+JSON.stringify( this.stockAdjustmentLine));
        this.isLoading = true;
        let transferlines = [];
        this.stockAdjustmentLine.forEach(element => {
            let temp = {
                rowNumber : element.rowNumber,
                productId : element.productId,
                productName : element.productName,
                isSerialControlProduct : element.isSerialControlProduct,
                stockingLocationId : element.stockingLocationId,
                inventoryId : element.inventoryId,
                inventoryName : element.inventoryName,
                QuantityOnHand : element.QuantityOnHand,
                newQuantity : element.newQuantity,
                action : element.action,
                AdjustmenType : element.AdjustmenType,
                adjustmentReason : element.adjustmentReason,
                serialList: element.serialList,
                serialNumberList: element.serialNumberList
            }
            transferlines.push(temp);
        });


        let transferData = JSON.stringify(transferlines);
        createStockAdjustment_Line({ 
            wareHouseId: this.mainStockingLocation.IMagic__Warehouse__c,
            stockingLocationId: this.sourceStockingLocationId,
            transferJson: transferData 
        })
        .then(result => {
            if(result){    
                this.showToast('Success','Stock Adjusted Successfully.','success');
                this.sourceStockingLocationId = this.mainStockingLocation.Id;
                this.sourceStockingLocationName = this.mainStockingLocation.Name;
                this.stockAdjustmentLine = [];
                this.isLoading = false;
                window.location.reload();
            }
            // Handle success response if needed
        })
        .catch(error => {
            this.isLoading = false;
            this.showToast('Error','Error in creating stock transfer: '+ error.body.message,'error');
            console.error('Error in creating stock transfer: ', error);
            // Handle error response if needed
        });
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

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
}