import { LightningElement, track, api } from 'lwc';
import getProducts from '@salesforce/apex/orderProductUnReserved.getProducts';
import unReservedOrderProduct from '@salesforce/apex/orderProductUnReserved.unReservedOrderProduct';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import OR_still from '@salesforce/resourceUrl/OR_still';
import RO_anim from '@salesforce/resourceUrl/RO_anim';
import PO_bgImage from '@salesforce/resourceUrl/PO_bgImage';


export default class OrderProductUnReserved extends LightningElement {
    get backgroundStyle() {
        // return `border:1px solid grey;height:auto;background-repeat: repeat;background-image:url(${PO_bgImage})`;
        return `height:auto;background-repeat: repeat-x;background-image:url(${PO_bgImage})`;
      }
      
      iconRO_anim=RO_anim;
      iconOR_still=OR_still;
    
    
      @api recordId;
      @track orderProducts = [];
      serialRecord;
      showSerialModal = false;
      @track isLoading = true;
    
    
      getNewObject() {
        return {
          Id: '',
          orderId: '',
          stockingLocationId: '',
          stockingLocationName: '',
          unitPrice: 0,
          quantityOrdered: 0,
          quantityReserved: 0,
          quantityRemaining: 0,
          newUnReservedQuantity: 0,
          productId: '',
          productName: '',
          productRecordTypeName: '',
          isSerialControlProduct: false,
          isBundleProduct: false,
          supplierId: '',
          supplierName: '',
          inventoryId: '',
          inventoryAvailableQuantity: 0,
          serialList: [],
          isSelected: false,
          get showSerialBtn(){
            return (this.isSerialControlProduct && this.newUnReservedQuantity > 0);
          },
          get minimumUnReservedQty(){
            return this.isSelected ? 1 : 0;
          },
          get disableInput(){
            return this.isSelected ? false : true;
          }
        };
      }

      connectedCallback() {
        const checkRecordId = setInterval(() => {
                this.loadOrderItems();
                clearInterval(checkRecordId); 
        }, 150); 
      }
    
      loadOrderItems() {
        this.isLoading = true;
        
        getProducts({ orderId: this.recordId })
            .then(result => {
                if (result) {
                    result.forEach(element => {
                        let tempObj = this.getNewObject();
                        tempObj.Id = element.Id;
                        tempObj.orderId = element.orderId;
                        tempObj.stockingLocationId = element.stockingLocationId;
                        tempObj.stockingLocationName = element.stockingLocationName;
                        tempObj.unitPrice = element.unitPrice;
                        tempObj.quantityOrdered = element.quantityOrdered;
                        tempObj.quantityReserved = element.quantityReserved;
                        tempObj.quantityRemaining = element.quantityRemaining;
                        tempObj.productId = element.productId;
                        tempObj.productName = element.productName;
                        tempObj.productRecordTypeName = element.productRecordTypeName;
                        tempObj.isSerialControlProduct = element.isSerialControlProduct;
                        tempObj.isBundleProduct = element.isBundleProduct;
                        tempObj.supplierId = element.supplierId;
                        tempObj.supplierName = element.supplierName;
                        tempObj.inventoryId = element.inventoryId;
                        tempObj.inventoryAvailableQuantity = element.inventoryAvailableQuantity;
                        this.orderProducts.push(tempObj);
                    });
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error fetching products:', error);
            });
      }
    
      
    handleAddSerialClick(event){
        let itemId = event.target.dataset.id; 
        const index = this.orderProducts.findIndex((element) => element.Id == itemId);
        let numOfSerials = 0;
        if(this.orderProducts[index].quantityReserved >= this.orderProducts[index].newUnReservedQuantity){
        numOfSerials = this.orderProducts[index].newUnReservedQuantity;
        }
        else{
        numOfSerials = this.orderProducts[index].inventoryAvailableQuantity;
        }
        let tempSerialRec = {
            numOfSerials: numOfSerials,
            serialList: this.orderProducts[index].serialList,
            sourceInvId: this.orderProducts[index].inventoryId,
            rowNum_OrderNum: null,
            orderItemId: itemId,
            queryFilters: ` AND IMagic__Quantity_on_Order__c > 0  `
        }
        this.serialRecord = tempSerialRec;
        this.showSerialModal = true;
    }

    handleCloseModal(){
        this.showSerialModal = false;
    }

    handleSaveSerials(event){
        const orderItemId = event.detail.orderItemId;
        const index = this.orderProducts.findIndex((element) => element.Id == orderItemId);
        this.orderProducts[index].serialList = event.detail.serialList;
        this.showSerialModal = false;
    }
    

    handleQtyChange(event) {
        
        const itemId = event.target.dataset.id;
        const value = event.detail.value;
        const index = this.orderProducts.findIndex((element) => element.Id == itemId);
        
        if (index !== -1) {
            this.orderProducts[index].newUnReservedQuantity = value;
            this.orderProducts[index].serialList = [];
        }
    }
    
    closeModal() {
        this.isModalOpen = false;
    }

    handleActionChange(event) {
        const itemId = event.target.dataset.id;
        const index = this.orderProducts.findIndex((element) => element.Id == itemId);
        this.orderProducts[index].isSelected = event.target.checked;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }

    handleCancel() {
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
    
      handleReserve() {
        if (this.orderProducts.length == 0) {
            this.showToast('Error', 'Atleast add one Product', 'error');
            return;
        }
        
        if(!this.isInputValid()){
          return
        }
    
        const selectedOrderProducts = this.orderProducts.filter(element => element.isSelected);
          
        if (selectedOrderProducts.length === 0) {
        this.showToast('Error', 'Please select at least one Product to process.', 'error');
        return;
        }
    
    
     
    
        const invalidSupplierRow = this.orderProducts.find(element => {
          // Check if the row is selected and if selectedType is null or empty
          if (element.isSelected && !element.supplierId) {
              return element;
          }
          return false;  // Skip rows that aren't selected or have a valid selectedType
        });
        if (invalidSupplierRow) {
            this.showToast('Error', `${invalidSupplierRow.productName} Supplier is missing`, 'error');
            return;
        }
    

        const invalidQuantityRow = this.orderProducts.find(element => {
            // Check if the row is selected and if selectedType is null or empty
            if (element.isSelected && element.isBundleProduct && element.newUnReservedQuantity > element.quantityReserved) {
                return element;
            }
            return false;  // Skip rows that aren't selected or have a valid selectedType
          });
        if(invalidQuantityRow) {
            this.showToast('Error', `The Unreserved quantity for ${invalidQuantityRow.productName} cannot exceed the Reserved quantity.`, 'error');
            return;
        }
        
    
        const invalidRow = this.orderProducts.find(element => {
          if (element.isSelected && element.isSerialControlProduct && element.newUnReservedQuantity > 0) {
              // Check if the serial number list is empty or has null values
              return element.serialList.length === 0 ||
                      element.serialList.some(serial => !serial.invDetailId);
          }
          return false;  // Skip rows that aren't selected or aren't serial controlled
          });
          if (invalidRow) {
          this.showToast('Error', `${invalidRow.productName} has missing serials`, 'error');
          return;
          }
          this.isLoading = true;
          // Gather selected purchase order lines
          const selectedPurchaseOrderLines = this.orderProducts.filter(element => element.isSelected);

          unReservedOrderProduct({ OrderLineJSON: JSON.stringify(selectedPurchaseOrderLines) })
            .then(result => {
                if(result){
                    this.showToast('Success', 'Products Unreserved Successfully', 'success');
                    this.dispatchEvent(new CloseActionScreenEvent());
                    this.isLoading = false;
                    this.loadOrderItems(this.recordId);
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to reserve products: ' + error.body.message, 'error');
            });
      }

      
}