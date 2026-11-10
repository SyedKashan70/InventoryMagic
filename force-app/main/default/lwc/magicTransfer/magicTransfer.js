import { LightningElement, wire, track } from 'lwc';
import getMainWarehouseStockingLocation from '@salesforce/apex/magicTransferController.getMainWarehouseStockingLocation';
import processOrderProducts from '@salesforce/apex/magicTransferController.processOrderProducts';
import createMagicTransfer_LineItem from '@salesforce/apex/magicTransferController.createMagicTransfer_LineItem';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import ST_still from '@salesforce/resourceUrl/ST_still';
import ST_anim from '@salesforce/resourceUrl/ST_anim';
import PO_bgImage from '@salesforce/resourceUrl/PO_bgImage';

export default class MagicTransfer extends LightningElement {

    get backgroundStyle() {
        return `height: 100vh;background-repeat: repeat-x;background-image:url(${PO_bgImage})`;
    }
    iconST_still=ST_still;
    iconST_anim=ST_anim;

    mainStockingLocation;
    @track magicTransferObject;
    showSerialModal = false;
    serialRecord;
    isLoading = false;

  

    destinationStockingLocationId = '';
    destinationStockingLocationName = '';
    destinationStockingLocation_QueryFields = '';
    destinationStockingLocation_OrderBy = ' Name ASC';
    destinationStockingLocation_RecordLimit = 100;
    get  destinationStockingLocation_QueryFilters(){
        let filter = ' IMagic__is_Main_Stocking_Location__c = FALSE ';
        if(this.mainStockingLocation.IMagic__Warehouse__c){
            filter += ' AND IMagic__Warehouse__c  = \'' + this.mainStockingLocation.IMagic__Warehouse__c + '\'';
        }
        return filter;
    }

    getNewObject() {
        return {
            rowNumber: 0,
            isSelected: false,
            orderId: "",
            orderNumber: "",
            orderItemId: "",
            orderItemQuantity : 0,
            orderItemTransferredQuantity: 0,
            orderItemTransferPendingQuantity: 0,
            selectedProductId: "",
            selectedProductName: "",
            isSerialControlProduct: false,
            sourceStockingLocationId:"",
            sourceStockingLocationName:"",
            sourceStockingLocationInventoryId: "",
            sourceStockingLocationInventoryName: "",
            destinationStockingLocationId:"",
            destinationStockingLocationName:"",
            destinationStockingLocationInventoryId: "",
            destinationStockingLocationInventoryName: "",
            sourceStockingLocationavailbleQuantity: 0,
            destinationStockingLocationavailbleQuantity: 0,
            transferQuantity: 0,
            serialList:[],
            get showSerialModalIcon(){
                return this.isSerialControlProduct == true && (this.transferQuantity > 0 && this.transferQuantity <= this.sourceStockingLocationavailbleQuantity);
            },
            get minTransferQuantity(){
                return this.isSelected ? 1 : 0;
            }
        };
    }

    @wire(getMainWarehouseStockingLocation)
    wiredStockingLocation({ error, data }) {
        if (data) {
            console.log('data LL '+JSON.stringify(data));
            this.mainStockingLocation = data;
        } else if (error) {
            console.log('Error in getMainWarehouseStockingLocation:'+JSON.stringify(error));
        }
    }

    destinationStockingLocationSelectionHandler(event){
        let recordDetail = event.detail.record;
        this.destinationStockingLocationId = recordDetail.Id;
        this.destinationStockingLocationName = recordDetail.Name;
        this.fetchOrderProducts(this.mainStockingLocation.IMagic__Warehouse__c,this.mainStockingLocation.Id,recordDetail.Id,recordDetail.Name);
    }

    destinationStockingLocationRemovedHandler(){
        this.destinationStockingLocationId = '';
        this.destinationStockingLocationName = '';
        this.magicTransferObject = [];
    }

    fetchOrderProducts(warehouseId, sourceLocationId, destinationLocationId,destinationLocationName) {
        processOrderProducts({ 
            wareHouseId: warehouseId, 
            sourceLocationId: sourceLocationId, 
            destinationLocationId: destinationLocationId,
            destinationLocationName: destinationLocationName
        })
        .then(data => {
            let magicTransferMap = new Map();
            let counter = 0;
            let magicTransferObject = [];
            for (const orderNumber in data) {
                if (data.hasOwnProperty(orderNumber)) {
                    
                    // Access items for the current order
                    const items = data[orderNumber];
                    // Loop through each item in the order
                    const magicLineList = [];
                    items.forEach(element => {
                        let tempObj = this.getNewObject();
                        tempObj.rowNumber = counter;
                        tempObj.orderId = element.orderId;
                        tempObj.orderNumber = element.orderNumber,
                        tempObj.orderItemId = element.orderItemId;
                        tempObj.orderItemQuantity = element.orderItemQuantity;
                        tempObj.orderItemTransferredQuantity = element.orderItemTransferredQuantity;
                        tempObj.orderItemTransferPendingQuantity = element.orderItemTransferPendingQuantity;
                        tempObj.selectedProductId = element.selectedProductId;
                        tempObj.selectedProductName = element.selectedProductName;
                        tempObj.isSerialControlProduct = element.isSerialControlProduct;  
                        tempObj.sourceStockingLocationId = element.sourceStockingLocationId;
                        tempObj.sourceStockingLocationName = element.sourceStockingLocationName;
                        tempObj.sourceStockingLocationInventoryId = element.sourceStockingLocationInventoryId;
                        tempObj.sourceStockingLocationInventoryName = element.sourceStockingLocationInventoryName;     
                        tempObj.destinationStockingLocationId = element.destinationStockingLocationId;
                        tempObj.destinationStockingLocationName = element.destinationStockingLocationName; 
                        tempObj.destinationStockingLocationInventoryId = element.destinationStockingLocationInventoryId;
                        tempObj.destinationStockingLocationInventoryName = element.destinationStockingLocationInventoryName;
                        tempObj.sourceStockingLocationavailbleQuantity = element.sourceStockingLocationavailbleQuantity;
                        tempObj.destinationStockingLocationavailbleQuantity = element.destinationStockingLocationavailbleQuantity;
                        
                        magicLineList.push(tempObj);
                        counter++;
                    });
                    magicTransferMap.set(String(orderNumber), magicLineList)
                }
            }

            magicTransferMap.forEach((value, key) => {
                magicTransferObject.push({"orderNumber": key, "magicLineList":value});
            });
            this.magicTransferObject = magicTransferObject;

        })
        .catch(error => {
            console.error('Error fetching stock transfer lines:', error);
        });
    }

    handleTransferQuantityChange(event){
        let rowOrderItemId = event.target.dataset.id; 
        let rowOrderNum = event.target.dataset.ordernum; 
        const parentIndex = this.magicTransferObject.findIndex((element) => element.orderNumber == rowOrderNum);
        if(parentIndex != -1){
            const childIndex = this.magicTransferObject[parentIndex].magicLineList.findIndex((element) => element.orderItemId == rowOrderItemId);
            if(childIndex != -1){
                this.magicTransferObject[parentIndex].magicLineList[childIndex].transferQuantity = event.detail.value;
                this.magicTransferObject[parentIndex].magicLineList[childIndex].serialList = [];
            }
        }
    }

    handleAddSerialClick(event){
        let rowOrderItemId = event.target.dataset.id; 
        let rowOrderNum = event.target.dataset.ordernum; 
        const parentIndex = this.magicTransferObject.findIndex((element) => element.orderNumber == rowOrderNum);
        if(parentIndex != -1){
            const childIndex = this.magicTransferObject[parentIndex].magicLineList.findIndex((element) => element.orderItemId == rowOrderItemId);
            if(childIndex != -1){
                let tempSerialRec = {
                    numOfSerials: this.magicTransferObject[parentIndex].magicLineList[childIndex].transferQuantity,
                    serialList: this.magicTransferObject[parentIndex].magicLineList[childIndex].serialList,
                    sourceInvId: this.magicTransferObject[parentIndex].magicLineList[childIndex].sourceStockingLocationInventoryId,
                    rowNum_OrderNum: rowOrderNum,
                    orderItemId: rowOrderItemId,
                    queryFilters: ` AND IMagic__Quantity_on_order__c > 0  `
                }
                this.serialRecord = tempSerialRec;
                this.showSerialModal = true;
            }
        }
    }

    handleCloseModal(){
        this.showSerialModal = false;
    }

    handleSaveSerials(event){
        const orderItemId = event.detail.orderItemId;
        const rowNum_OrderNum = event.detail.rowNum_OrderNum;
        const parentIndex = this.magicTransferObject.findIndex((element) => element.orderNumber == rowNum_OrderNum);
        if(parentIndex != -1){
            const childIndex = this.magicTransferObject[parentIndex].magicLineList.findIndex((element) => element.orderItemId == orderItemId);
            if(childIndex != -1){
                this.magicTransferObject[parentIndex].magicLineList[childIndex].serialList = event.detail.serialList;
            }
        }
        this.showSerialModal = false;
    }

    handleCheckboxChange(event){
        let rowOrderItemId = event.target.dataset.id; 
        let rowOrderNum = event.target.dataset.ordernum; 
        const parentIndex = this.magicTransferObject.findIndex((element) => element.orderNumber == rowOrderNum);
        if(parentIndex != -1){
            const childIndex = this.magicTransferObject[parentIndex].magicLineList.findIndex((element) => element.orderItemId == rowOrderItemId);
            if(childIndex != -1){
                this.magicTransferObject[parentIndex].magicLineList[childIndex].isSelected = event.target.checked;   
            }
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

    handleSave() {
        if (!this.destinationStockingLocationId) {
            this.showToast('Error', 'Destination Stocking Location cannot be null or empty.', 'error');
            return;
        }
        
        if (this.magicTransferObject.length === 0) {
            this.showToast('Error', 'No Stock Available to Transfer', 'error');
            return;
        }

        const selectedPurchaseOrderLines = this.magicTransferObject
        .flatMap(order => order.magicLineList) // Flatten the magicLineList array from each order
        .filter(item => item.isSelected); // Filter items where isSelected is true

        if (selectedPurchaseOrderLines.length === 0) {
            this.showToast('Error', 'Please select at least one Product to process.', 'error');
            return;
        }

        if(!this.isInputValid()){
            return
        }

        const invalidRow = this.magicTransferObject
        .flatMap(order => order.magicLineList) // Flatten the magicLineList arrays across orders
        .find(item => {
            if (item.isSerialControlProduct && item.isSelected) {
            // Check if serialList is empty or has any serial entry missing invDetailId
            return item.serialList.length === 0 || 
                    item.serialList.some(serial => !serial.invDetailId);
            }
            return false;
        });
        if (invalidRow) {
            this.showToast('Error', ` Product Name ${invalidRow.selectedProductName} in Order ${invalidRow.orderNumber} has missing serials`, 'error');
            return;
        }

        this.isLoading = true;
        // Save logic here
        let transferlines = [];
        this.magicTransferObject.forEach(order => {
            order.magicLineList.forEach(element => {
                if(element.isSelected){
                    let temp = {
                        orderId : element.orderId,
                        orderNumber : element.orderNumber,
                        orderItemId : element.orderItemId,
                        orderItemQuantity : element.orderItemQuantity,
                        orderItemTransferredQuantity : element.orderItemTransferredQuantity,
                        orderItemTransferPendingQuantity : element.orderItemTransferPendingQuantity,
                        selectedProductId : element.selectedProductId,
                        selectedProductName : element.selectedProductName,
                        isSerialControlProduct : element.isSerialControlProduct,
                        sourceStockingLocationId : element.sourceStockingLocationId,
                        sourceStockingLocationName : element.sourceStockingLocationName,
                        sourceStockingLocationInventoryId : element.sourceStockingLocationInventoryId,
                        sourceStockingLocationInventoryName: element.sourceStockingLocationInventoryName,
                        destinationStockingLocationId : element.destinationStockingLocationId,
                        destinationStockingLocationName : element.destinationStockingLocationName,  
                        destinationStockingLocationInventoryId : element.destinationStockingLocationInventoryId,
                        destinationStockingLocationInventoryName : element.destinationStockingLocationInventoryName,
                        sourceStockingLocationavailbleQuantity : element.sourceStockingLocationavailbleQuantity,
                        destinationStockingLocationavailbleQuantity : element.destinationStockingLocationavailbleQuantity,
                        transferQuantity : element.transferQuantity,
                        serialList: element.serialList
                    }
                    transferlines.push(temp);
                }
            });
        });
        let transferData = JSON.stringify(transferlines);
        createMagicTransfer_LineItem({ 
            wareHouseId: this.mainStockingLocation.IMagic__Warehouse__c,
            transferJson: transferData 
        })
        .then(result => {
            if(result){    
                this.showToast('Success','Magic Transfered successfully.','success');
                this.destinationStockingLocationId = '';
                this.destinationStockingLocationName = '';
                this.magicTransferObject = [];
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
}