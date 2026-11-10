import { LightningElement,track } from 'lwc';
import LightningConfirm from 'lightning/confirm';
import getInventoryRecords from '@salesforce/apex/StockTransferController.getInventoryRecords';
import createStockTransfer_LineItem from '@salesforce/apex/StockTransferController.createStockTransfer_LineItem';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import ST_anim from '@salesforce/resourceUrl/ST_anim';
import ST_still from '@salesforce/resourceUrl/ST_still';
import PO_bgImage from '@salesforce/resourceUrl/PO_bgImage';

export default class StockTransfer extends LightningElement {

    get backgroundStyle() {
        return `max-height:calc(100vh - 150px);overflow: auto; height:auto;padding: 10px; border:1px solid grey;background-repeat: repeat;background-image:url(${PO_bgImage})`;
    }

    iconST_anim=ST_anim;
    iconST_still=ST_still;

    @track stockTransferTable = [];
    isMultiWarehouseTransfer = false;
    showSerialModal = false;
    serialRecord;
    isLoading = false;

    get disableScreen(){
        if(!this.sourceWarehouseId){
            return true;
        }
        return false;
    }

    
    sourceWarehouseId = '';
    sourceWarehouseName = '';
    sourceWarehouse_QueryFields = '';
    sourceWarehouse_OrderBy = ' Name ASC';
    sourceWarehouse_QueryFilters = '';
    sourceWarehouse_RecordLimit = 100;

    sourceStockingLocation_QueryFields = '';
    sourceStockingLocation_OrderBy = ' Name ASC';
    sourceStockingLocation_RecordLimit = 100;
    get  sourceStockingLocation_QueryFilters(){
        return this.sourceWarehouseId ? ' IMagic__Warehouse__c  = \'' + this.sourceWarehouseId + '\'' : '';
    }

    product_QueryFields = ' IMagic__Product__c, IMagic__Product__r.Name,Product__r.RecordType.Name,IMagic__Quantity_on_Hand__c,IMagic__Product_Name__c ';
    product_OrderBy = ' IMagic__Product_Name__c ASC';
    product_RecordLimit = 100;
    product_selectedValueName = 'Id';
    product_selectedLabelName = 'IMagic__Product_Name__c';

    
    destinationWarehouseId = '';
    destinationWarehouseName = '';
    destinationWarehouse_QueryFields = '';
    destinationWarehouse_OrderBy = ' Name ASC';
    destinationWarehouse_QueryFilters = '';
    destinationWarehouse_RecordLimit = 100;

    destinationStockingLocation_QueryFields = '';
    destinationStockingLocation_OrderBy = ' Name ASC';
    destinationStockingLocation_RecordLimit = 100;
    // get destinationStockingLocation_QueryFilters(){
        // if(this.isMultiWarehouseTransfer){
        //     return ' IMagic__Warehouse__c  = \'' + this.destinationWarehouseId + '\'';
        // }
        // else{
        //     return ' IMagic__Warehouse__c  = \'' + this.sourceWarehouseId + '\'';
        // }
    // }

    sourceWarehouseSelectionHandler(event){
        let recordDetail = event.detail.record;
        this.sourceWarehouseId = recordDetail.Id;
        this.sourceWarehouseName = recordDetail.Name;
        this.stockTransferTable = [];
    }

    sourceWarehouseRemovedHandler(){
        this.sourceWarehouseId = '';
        this.sourceWarehouseName = '';
        this.stockTransferTable = [];
    }

    sourceStockingLocationSelectionHandler(event){
        let rowNum = event.target.dataset.id; 
        let recordDetail =event.detail.record;
        const index = this.stockTransferTable.findIndex((element) => element.rowNumber == rowNum);
        this.stockTransferTable[index].sourceStockingLocationId = recordDetail.Id;
        this.stockTransferTable[index].sourceStockingLocationName = recordDetail.Name;
    }

    sourceStockingLocationRemovedHandler(event){
        let rowNum = event.target.dataset.id; 
        const index = this.stockTransferTable.findIndex((element) => element.rowNumber == rowNum);
        this.stockTransferTable[index].sourceStockingLocationId = '';
        this.stockTransferTable[index].sourceStockingLocationName = '';
        this.stockTransferTable[index].selectedProductId = '';
        this.stockTransferTable[index].selectedProductName = '';
        this.stockTransferTable[index].sourceStockingLocationavailbleQuantity = 0;
        this.stockTransferTable[index].transferQuantity = 0;
        this.stockTransferTable[index].sourceStockingLocationInventoryId = ''
        this.stockTransferTable[index].sourceStockingLocationInventoryName = '';
        this.stockTransferTable[index].isSerialControlProduct = false;
        this.stockTransferTable[index].destinationStockingLocationId = ''
        this.stockTransferTable[index].destinationStockingLocationName = '';
        this.stockTransferTable[index].destinationStockingLocationInventoryId = ''
        this.stockTransferTable[index].destinationStockingLocationInventoryName = '';
        this.stockTransferTable[index].description = '';
    }

    productSelectionHandler(event){
        let rowNum = event.target.dataset.id; 
        let recordDetail =event.detail.record ;
        const index = this.stockTransferTable.findIndex((element) => element.rowNumber == rowNum);
        
        this.stockTransferTable[index].selectedProductId = recordDetail.IMagic__Product__r.Id;
        this.stockTransferTable[index].selectedProductName = recordDetail.IMagic__Product__r.Name;
        this.stockTransferTable[index].sourceStockingLocationavailbleQuantity = recordDetail.IMagic__Quantity_on_Hand__c;
        this.stockTransferTable[index].sourceStockingLocationInventoryId = recordDetail.Id;
        this.stockTransferTable[index].sourceStockingLocationInventoryName = recordDetail.Name;
        this.stockTransferTable[index].isSerialControlProduct = recordDetail.IMagic__Product__r.RecordType.Name == 'Serial Control' ? true : false;
    }

    productRemovedHandler(event){
        let rowNum = event.target.dataset.id; 
        const index = this.stockTransferTable.findIndex((element) => element.rowNumber == rowNum);
        this.stockTransferTable[index].selectedProductId = '';
        this.stockTransferTable[index].selectedProductName = '';
        this.stockTransferTable[index].sourceStockingLocationavailbleQuantity = 0;
        this.stockTransferTable[index].sourceStockingLocationInventoryId = '';
        this.stockTransferTable[index].sourceStockingLocationInventoryName = '';
        this.stockTransferTable[index].isSerialControlProduct = false;
        this.stockTransferTable[index].transferQuantity = 0;
        this.stockTransferTable[index].destinationStockingLocationId = ''
        this.stockTransferTable[index].destinationStockingLocationName = '';
        this.stockTransferTable[index].destinationStockingLocationInventoryId = ''
        this.stockTransferTable[index].destinationStockingLocationInventoryName = '';
        this.stockTransferTable[index].description = '';
    }

    destinationWarehouseSelectionHandler(event){
        let recordDetail = event.detail.record;
        this.destinationWarehouseId = recordDetail.Id;
        this.destinationWarehouseName = recordDetail.Name;
    }

    destinationWarehouseRemovedHandler(event){
        this.destinationWarehouseId = '';
        this.destinationWarehouseName = '';
    }

    async destinationStockingLocationSelectionHandler(event){
        let rowNum = event.target.dataset.id; 
        let recordDetail =event.detail.record;
        const index = this.stockTransferTable.findIndex((element) => element.rowNumber == rowNum);
        this.stockTransferTable[index].destinationStockingLocationId = recordDetail.Id;
        this.stockTransferTable[index].destinationStockingLocationName = recordDetail.Name;
        let relatedInventoryRecord = await this.getDestinationStockingLocationInventory(this.stockTransferTable[index].selectedProductId, recordDetail.Id);
        this.stockTransferTable[index].destinationStockingLocationInventoryId = relatedInventoryRecord.Id;
        this.stockTransferTable[index].destinationStockingLocationInventoryName = relatedInventoryRecord.Name;
        this.stockTransferTable[index].destinationStockingLocationavailbleQuantity = relatedInventoryRecord.IMagic__Quantity_on_Hand__c;
    }

    destinationStockingLocationRemovedHandler(event){
        let rowNum = event.target.dataset.id; 
        const index = this.stockTransferTable.findIndex((element) => element.rowNumber == rowNum);
        this.stockTransferTable[index].destinationStockingLocationId = '';
        this.stockTransferTable[index].destinationStockingLocationName = '';
        this.stockTransferTable[index].destinationStockingLocationInventoryId = '';
        this.stockTransferTable[index].destinationStockingLocationInventoryName = '';
        this.stockTransferTable[index].destinationStockingLocationavailbleQuantity = 0;
        this.stockTransferTable[index].transferQuantity = 0;
        this.stockTransferTable[index].description = '';
    }

    handleTransferQuantityChange(event){
        let rowNum = event.target.dataset.id; 
        const index = this.stockTransferTable.findIndex((element) => element.rowNumber == rowNum);
       
        const isSerialControlProduct = this.stockTransferTable[index].isSerialControlProduct;

       

        this.stockTransferTable[index].transferQuantity = event.detail.value;
        this.stockTransferTable[index].serialList = [];
   
        if(isSerialControlProduct){
            this.template.querySelector('lightning-input[data-name="width').classList.add('btn-width');
        }
    }

    handleDescriptionChange(event){
        let rowNum = event.target.dataset.id; 
        const index = this.stockTransferTable.findIndex((element) => element.rowNumber == rowNum);
        this.stockTransferTable[index].description = event.detail.value;
    }

    getIndex() {
        return this.stockTransferTable.length;
    }

    getNewObject() {
        return {
            rowNumber: this.getIndex(),
            sourceWarehouseId: "",
            destinationWarehouseId: "",
            sourceStockingLocationId: "",
            sourceStockingLocationName: "",
            sourceStockingLocationInventoryId: "",
            sourceStockingLocationInventoryName: "",
            destinationStockingLocationId: "",
            destinationStockingLocationName: "",
            destinationStockingLocationInventoryId: "",
            destinationStockingLocationInventoryName: "",
            selectedProductId: "",
            selectedProductName: "",
            isSerialControlProduct: false,
            sourceStockingLocationavailbleQuantity: 0,
            destinationStockingLocationavailbleQuantity: 0,
            transferQuantity: 0,
            description: "",
            serialList:[],
            get  product_QueryFilters(){
                return ' IMagic__Stocking_Location__c   = \'' + this.sourceStockingLocationId + '\' AND IMagic__Quantity_on_Hand__c > 0';
            },
            get destinationStockingLocation_QueryFilters(){
                if(this.destinationWarehouseId){
                    return ' IMagic__Warehouse__c  = \'' + this.destinationWarehouseId + '\'';
                }
                else{
                    return ' IMagic__Warehouse__c  = \'' + this.sourceWarehouseId + '\' AND Id != \'' + this.sourceStockingLocationId + '\'';
                }
            },
            get showSerialModalIcon(){
                return this.isSerialControlProduct == true && (this.transferQuantity > 0 && this.transferQuantity <= this.sourceStockingLocationavailbleQuantity);
            },
            get disableProduct(){
                return this.sourceStockingLocationId ? false : true;
            },
            get disableDestinationLocation(){
                return this.selectedProductId ? false : true;
            }
        };
    }

    handleAddRow() {
        let tempObj = this.getNewObject();
        tempObj.sourceWarehouseId = this.sourceWarehouseId;
        tempObj.destinationWarehouseId = this.destinationWarehouseId;
        let tempArray = [...this.stockTransferTable]; 
        tempArray.push(tempObj);
        this.stockTransferTable = tempArray;
    }

    async handleToggleMultiWarehouseTransfer(){
        const result = await LightningConfirm.open({
            message: 'Are you Sure?',
            variant: 'headerless',
            label: 'Are you Sure',
            // setting theme would have no effect
        });
        if(result){
            this.isMultiWarehouseTransfer = !this.isMultiWarehouseTransfer;
            this.stockTransferTable = [];
        }
        else{
            this.isMultiWarehouseTransfer = this.isMultiWarehouseTransfer;
        }
    }

    handleAddSerialClick(event){
        let rowNum = event.target.dataset.id; 
        const index = this.stockTransferTable.findIndex((element) => element.rowNumber == rowNum);
        let tempSerialRec = {
            numOfSerials: this.stockTransferTable[index].transferQuantity,
            serialList: this.stockTransferTable[index].serialList,
            sourceInvId: this.stockTransferTable[index].sourceStockingLocationInventoryId,
            rowNum_OrderNum: rowNum,
            orderItemId: null,
            queryFilters: ` AND Quantity__c > 0  `
        }
        this.serialRecord = tempSerialRec;
        this.showSerialModal = true;
    }

    handleCloseModal(){
        this.showSerialModal = false;
    }

    handleSaveSerials(event){
        const sourceInvId = event.detail.sourceInvId;
        const index = this.stockTransferTable.findIndex((element) => element.sourceStockingLocationInventoryId == sourceInvId);
        this.stockTransferTable[index].serialList = event.detail.serialList;
        this.showSerialModal = false;
    }

    handleSave() {
        if (!this.sourceWarehouseId) {
            this.showToast('Error', 'Source Warehouse cannot be null or empty.', 'error');
            return;
        }
        
        if (this.stockTransferTable.length === 0) {
            this.showToast('Error', 'No Stock Available to Transfer', 'error');
            return;
        }

        if(!this.isInputValid()){
            return
        }

        const invalidRow = this.stockTransferTable.find(element => {
            if (element.isSerialControlProduct && element.sourceStockingLocationavailbleQuantity > 0) {
                // Check if the serial number list is empty or has null values
                return element.serialList.length === 0 ||
                        element.serialList.some(serial => !serial.invDetailId);
            }
            return false;  // Skip rows that aren't selected or aren't serial controlled
            });
            if (invalidRow) {
            this.showToast('Error', `${invalidRow.selectedProductName} has missing serials`, 'error');
            return;
            }


        // Save logic here
        this.isLoading = true;
        let transferlines = [];
        this.stockTransferTable.forEach(element => {
            let temp = {
                selectedProductId : element.selectedProductId,
                selectedProductName : element.selectedProductName,
                isSerialControlProduct : element.isSerialControlProduct,
                sourceStockingLocationId : element.sourceStockingLocationId,
                sourceStockingLocationName: element.sourceStockingLocationName,
                sourceStockingLocationInventoryId : element.sourceStockingLocationInventoryId,
                sourceStockingLocationInventoryName: element.sourceStockingLocationInventoryName,
                destinationStockingLocationId : element.destinationStockingLocationId,
                destinationStockingLocationName: element.destinationStockingLocationName,
                destinationStockingLocationInventoryId : element.destinationStockingLocationInventoryId,
                destinationStockingLocationInventoryName : element.destinationStockingLocationInventoryName,
                sourceStockingLocationavailbleQuantity : element.sourceStockingLocationavailbleQuantity,
                destinationStockingLocationavailbleQuantity : element.destinationStockingLocationavailbleQuantity,
                transferQuantity : element.transferQuantity,
                serialList: element.serialList
            }
            transferlines.push(temp);
        });
        let transferData = JSON.stringify(transferlines);
        createStockTransfer_LineItem({ 
            sourceWarehouseId: this.sourceWarehouseId,
            destinationWarehouseId: this.destinationWarehouseId,
            isMultiWarehouseTransfer: this.isMultiWarehouseTransfer,
            transferJson: transferData 
        })
        .then(result => {
            if(result){    
                this.showToast('Success','Stock transfered successfully.','success');
                this.sourceWarehouseId = '';
                this.sourceWarehouseName = '';
                this.stockTransferTable = [];
                this.isLoading = false;
                window.location.reload()
            }
            // Handle success response if needed
        })
        .catch(error => {
            this.showToast('Error','Error in creating stock transfer: '+ error.body.message,'error');
            console.error('Error in creating stock transfer: ', error);
            this.isLoading = false;
            // Handle error response if needed
        });
    }

    async getDestinationStockingLocationInventory(productId, stockingLocationId) {
        try {
            let result = await getInventoryRecords({ productId: productId, stockingLocationId: stockingLocationId });
            return result;
        } catch (error) {
            console.log('getDestinationStockingLocationInventory : ' + JSON.stringify(error));
            return null;
        }
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

    handleDeleteRow(event){
        let rowNum = event.target.dataset.id; 
        const index = this.stockTransferTable.findIndex((element) => element.rowNumber == rowNum);
        if (index !== -1) {
            this.stockTransferTable = [
                ...this.stockTransferTable.slice(0, index),
                ...this.stockTransferTable.slice(index + 1)
            ];
        }
    }
}