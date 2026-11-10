import { LightningElement, api, wire, track } from 'lwc';
import getPurchaseOrderLines from '@salesforce/apex/PurchaseOrderLinesController.getPurchaseOrderLines';
import updatePurchaseOrderLines from '@salesforce/apex/PurchaseOrderLinesController.updatePurchaseOrderLines';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { CloseActionScreenEvent } from 'lightning/actions';

import PO_still from '@salesforce/resourceUrl/PO_still';
import PO_anim from '@salesforce/resourceUrl/PO_anim';
import PO_bgImage from '@salesforce/resourceUrl/PO_bgImage';

export default class PurchaseOrderLines extends NavigationMixin(LightningElement) {

    get backgroundStyle() {
        return `height:auto;background-repeat: repeat-x;background-image:url(${PO_bgImage})`;
    }
    iconPO_anim=PO_anim;
    iconPO_still=PO_still;

    @api recordId;
    @track purchaseOrderLines=[];
    isLoading = true;
    showSerialNumberModal = false;
    rowDetail = {};

    getNewObject(){
        return {
            Id: '',
            quantityOrdered: 0,
            recievedQuantity: 0,
            maxNewQuantity: 0,
            newQuantity: 0,
            unitPrice: 0,
            productId: '',
            productName: '',
            productDescription: '',
            productRecordTypeName: '',
            isSerialControlProduct: false,
            serialNumberList: [],
            inventoryId: '',
            inventoryCost: '',
            orderProduct: '',
            stockingLocation: '',
            isSelected: false,
            showSerialNumberModalIcon: false,
            purchaseOrderRecordTypeName: '',
            calculateAveragePriceForInv: false,
            get minimumRecieveQty(){
                return this.isSelected ? 1 : 0;
            },
            get disableInput(){
              return this.isSelected ? false : true;
            },
            get totalCost(){
                return this.newQuantity * this.unitPrice;
            }
        }
    }
    
    wiredPoLineItemsResult;
    @wire(getPurchaseOrderLines, { purchaseOrderId: "$recordId" })
    getPurchaseOrderLine(result)
    {
        this.wiredPoLineItemsResult = result;
        if(result.data)
        {
            console.log('Results: ' + JSON.stringify(result.data));
            this.populateData(result.data);
            this.isLoading = false;
        }
        else if(result.error)
        {
            this.isLoading = false;
            console.log('error: ' + JSON.stringify(result.error));
        }
    }

    populateData(value){
        value.forEach(element => {
            let tempObj =  this.getNewObject();
            tempObj.Id = element.Id;
            tempObj.quantityOrdered = element.quantityOrdered != null ? element.quantityOrdered : 0;
            tempObj.recievedQuantity = element.recievedQuantity != null ? element.recievedQuantity : 0;
            tempObj.maxNewQuantity = (element.quantityOrdered - element.recievedQuantity);
            tempObj.newQuantity = element.newQuantity != null ? element.newQuantity : 0;
            tempObj.unitPrice = element.unitPrice != null ? element.unitPrice : 0;
            tempObj.productId = element.productId != null ? element.productId : '';
            tempObj.productName = element.productName != null ? element.productName : '';
            tempObj.productDescription = element.productDescription != null ? element.productDescription : '';
            tempObj.productRecordTypeName = element.productRecordTypeName != null ? element.productRecordTypeName : '';
            tempObj.isSerialControlProduct = element.isSerialControlProduct != null ? element.isSerialControlProduct : false;
            tempObj.serialNumberList = element.serialNumberList != null ? element.serialNumberList : [];
            tempObj.inventoryId = element.inventoryId != null ? element.inventoryId : '';
            tempObj.inventoryCost = element.inventoryCost != null ? element.inventoryCost : 0;
            tempObj.calculateAveragePriceForInv = element.calculateAveragePriceForInv;
            tempObj.orderProduct = element.orderProduct != null ? element.orderProduct : '';
            tempObj.stockingLocation = element.stockingLocation != null ? element.stockingLocation : '';
            tempObj.isSelected = false;
            tempObj.showSerialNumberModalIcon = (element.newQuantity > 0 && element.newQuantity <= tempObj.maxNewQuantity && element.isSerialControlProduct) ? true : false;
            tempObj.purchaseOrderRecordTypeName = element.purchaseOrderRecordTypeName;
            this.purchaseOrderLines.push(tempObj);
        });
    }
    
    handleCheckboxChange(event) {
        const rowId = event.target.dataset.id;
        const index = this.purchaseOrderLines.findIndex((element) => element.Id == rowId);
        this.purchaseOrderLines[index].isSelected = event.target.checked;
    }

    setDefaultPurchasePrice(event) {
        const rowId = event.target.dataset.id;
        const index = this.purchaseOrderLines.findIndex((element) => element.Id == rowId);
        if (index !== -1) {
            this.purchaseOrderLines[index].unitPrice = this.purchaseOrderLines[index].inventoryCost;
        } 
    }

    handleQuantityChange(event) {
        const rowId = event.target.dataset.id;
        const index = this.purchaseOrderLines.findIndex((element) => element.Id == rowId);
        if (index !== -1) {
            const isSerialControlProduct = this.purchaseOrderLines[index].isSerialControlProduct;
            if(isSerialControlProduct){
                this.template.querySelector('lightning-input[data-name="width').classList.add('btn-width');
            }
            const newMaxQty = (this.purchaseOrderLines[index].quantityOrdered - this.purchaseOrderLines[index].recievedQuantity);
            
            this.purchaseOrderLines[index].newQuantity = event.detail.value;
            this.purchaseOrderLines[index].serialNumberList = [];
            this.purchaseOrderLines[index].showSerialNumberModalIcon = (event.detail.value > 0 && event.detail.value <= newMaxQty && isSerialControlProduct) ? true : false;
        } 
    }

    handleUnitPriceChange(event) {
        const rowId = event.target.dataset.id;
        const index = this.purchaseOrderLines.findIndex((element) => element.Id == rowId);
        if (index !== -1) {
            this.purchaseOrderLines[index].unitPrice = event.detail.value;
        } 
    }

    handleSerialNumberModalClick(event){
        const rowId = event.target.dataset.id;
        const index = this.purchaseOrderLines.findIndex((element) => element.Id == rowId);
        let tempRowDetail = {
            Id: this.purchaseOrderLines[index].Id,
            newQuantity: this.purchaseOrderLines[index].newQuantity,
            serialNumberList: this.purchaseOrderLines[index].serialNumberList,
            rowNum_Id: null
        }
        this.rowDetail = tempRowDetail;
        this.showSerialNumberModal = !this.showSerialNumberModal;
    }

    handleSaveSerialNumbers(event) {
        const rowId = event.detail.rowId;
        const index = this.purchaseOrderLines.findIndex((element) => element.Id == rowId);
        if (index !== -1) {
            this.purchaseOrderLines[index].serialNumberList = event.detail.serialNumbers;
        } 
        this.showSerialNumberModal = false;
    }

    handleCloseModal() {
        this.showSerialNumberModal = false;
    }
   
    handleSave() {
        if (!this.isInputValid()) {
        return;
        }
        
        // Validate if all selected serial control products have serial numbers
        const invalidRow = this.purchaseOrderLines.find(element => {
        if (element.isSelected && element.isSerialControlProduct) {
            // Check if the serial number list is empty or has null values
            return element.serialNumberList.length === 0 ||
                    element.serialNumberList.some(serialNum => serialNum.serialNumber === null);
        }
        return false;  // Skip rows that aren't selected or aren't serial controlled
        });
        
        if (invalidRow) {
        this.showToast('Error', `${invalidRow.productName} has missing serial numbers`, 'error');
        return;
        }
        
        // Gather selected purchase order lines
        const selectedPurchaseOrderLines = this.purchaseOrderLines.filter(element => element.isSelected);
        
        if (selectedPurchaseOrderLines.length === 0) {
        this.showToast('Error', 'Please select at least one purchase order line to process.', 'error');
        return;
        }
        
        this.isLoading = true;
        // Proceed with updating selected purchase order lines
        updatePurchaseOrderLines({ orderLinesJSON: JSON.stringify(selectedPurchaseOrderLines) ,purchaseOrderId: this.recordId})
        .then((result) => {
            if(result){
                refreshApex(this.wiredPoLineItemsResult);
                this.showToast('Success', 'Purchase Order Lines updated successfully', 'success');
                this.closeQuickAction();
                this.isLoading = false;
            }
        })
        .catch(error => {
            this.isLoading = false;
            this.showToast('Error', `Error updating Purchase Order Lines: ${error.body.message}`, 'error');
        });
    }

    handleCancel() {
        this.closeQuickAction();
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
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
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}