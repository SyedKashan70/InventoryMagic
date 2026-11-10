import { LightningElement,track,api} from 'lwc';
import getProductList from '@salesforce/apex/createBulkPOController.getProductList';
import createPurchaseOrders from '@salesforce/apex/createBulkPOController.createBulkPurchaseOrders';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from "lightning/actions";

import PSE_logo from '@salesforce/resourceUrl/PSE_logo_2';
import PO_bgImage from '@salesforce/resourceUrl/PO_bgImage';

export default class CreateBulkPO extends LightningElement {

    get backgroundStyle() {
        return `height:auto;background-repeat: repeat;background-image:url(${PO_bgImage})`;
    }
    iconPSE_logo=PSE_logo;

    @track isLoading = true;
    @track inventoryRecords = [];
    @track startDate;
    @track endDate;
    @track hideZeroQoh = true;
    @track useAvailQtyToReorder = false;
    @track showSelectedOnly = false;
    @track currentPage = 1;
    @track pageSize = 25;

    @api recordId;

    connectedCallback() {
        this.fetchInventoryRecords();
    }

    get totalPages() {
        return Math.ceil(this.filteredInventoryRecords.length / this.pageSize);
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    get paginatedRecords() {
        const startIdx = (this.currentPage - 1) * this.pageSize;
        const endIdx = startIdx + this.pageSize;
        return this.filteredInventoryRecords.slice(startIdx, endIdx);
    }

    get filteredInventoryRecords() {
        let records = this.inventoryRecords;

        // Apply filter to hide zero QOH or use available quantity for reorder
        if (this.hideZeroQoh || this.useAvailQtyToReorder) {
            records = records.filter(record => record.Lodestone__Quantity_On_Hand__c > 0);
        }

        // Apply filter to show only selected records if 'showSelectedOnly' is true
        if (this.showSelectedOnly) {
            records = records.filter(record => record.isSelected);
        }

        // Filter based on selected vendor
        if (this.selectedVendorId) {
            records = records.filter(record => record.Lodestone__Supplier__c === this.selectedVendorId);
        }

        // Filter based on selected product
        if (this.selectedProductId) {
            records = records.filter(record => record.Name === this.selectedProductId);
        }

        return records;
    }

    fetchInventoryRecords() {
        this.isLoading = true;
        // Mock data fetching, set `isLoading` to false when complete
        setTimeout(() => {
            getProductList({ recordId: this.recordId ,startDate: this.startDate, endDate: this.endDate })
            .then((data) => {
                // Set all products as selected by default
                this.inventoryRecords = data.map(record => ({
                    ...record,
                    isSelected: true  // Set `isSelected` to true by default
                }));
                this.isLoading = false;
            })
            .catch((error) => {
                console.log('Error:', JSON.stringify(error));
                this.inventoryRecords = [];
                this.isLoading = false;
            });
            this.isLoading = false;
        }, 200); // Simulate a delay
    }

    handleDateChange(event) {
        const field = event.target.name;
        if (field === 'startDate') {
            this.startDate = event.target.value;
        } else if (field === 'endDate') {
            this.endDate = event.target.value;
        }
        // Refresh inventory list based on new date range
        this.fetchInventoryRecords();
    }

    handleHideZeroQohChange(event) {
        this.hideZeroQoh = event.target.checked;
        this.currentPage = 1;
    }

    handleUseAvailQtyToReorderChange(event) {
        this.useAvailQtyToReorder = event.target.checked;
        this.currentPage = 1;
    }

    handleShowSelectedInventoryChange(event) {
        this.showSelectedOnly = event.target.checked;
        this.currentPage = 1;
    }

    handleProductCheckboxChange(event) {
        const productId = event.target.dataset.id;
        const selectedProduct = this.inventoryRecords.find(record => record.Id === productId);
        if (selectedProduct) {
            selectedProduct.isSelected = event.target.checked;
        }
    }

    handleCreatePurchaseOrders() {

        const orderQuantities = [];
    
        this.inventoryRecords.forEach(record => {
            
            const meetsReorderCondition = !(this.hideZeroQoh || this.useAvailQtyToReorder) || record.Lodestone__Quantity_On_Hand__c > 0;
    
            if (meetsReorderCondition && record.isSelected) {
                let orderQuantity;
    
                // If 'Use Available Qty to Reorder' is selected, set OrderQuantity to Lodestone__Quantity_On_Hand__c
                if (this.useAvailQtyToReorder) {
                    orderQuantity = record.Lodestone__Quantity_On_Hand__c;
                } else {
                    // Else, calculate OrderQuantity as IMagic__Reorder_Level__c - Lodestone__Quantity_On_Hand__c
                    orderQuantity = record.IMagic__Reorder_Level__c - record.Lodestone__Quantity_On_Hand__c;
                    // Ensure that the order quantity is not negative
                    orderQuantity = Math.max(orderQuantity, 0);
                }

                orderQuantities.push({
                    ProductId: record.Id,
                    OrderQuantity: orderQuantity
                });
            }
        });
    
        // Log the calculated quantities
        console.log('Calculated Order Quantities:', JSON.stringify(orderQuantities));

        if(orderQuantities.length === 0) {
            alert('No products were selected.');
            return;
        }

        this.isLoading = true;

        createPurchaseOrders({ orderQuantitiesJson: JSON.stringify(orderQuantities), warehouseId: this.recordId })
        .then(result => {
            this.showToast('Success', 'Purchase Orders created successfully.', 'success');
            console.log('Purchase Orders created successfully.');
            this.closeQuickAction();
            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error creating Purchase Orders:', error);
            this.showToast('Error', 'Failed to create Purchase Orders. Please try again.', 'error');
            this.isLoading = false;
        });
    }

    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage += 1;
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

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }


    product_QueryFields = ' RecordTypeId,RecordType.Name ';
    product_OrderBy = ' Name  ASC';
    product_RecordLimit = 100;
    get product_QueryFilters(){
        let filter = ' ';
        return filter;
    }

    account_QueryFields = ' RecordTypeId,RecordType.Name ';
    account_OrderBy = ' Name  ASC';
    account_RecordLimit = 100;
    get account_QueryFilters(){
        let filter = ' ';
        return filter;
    }

    selectedProductId = '';
    selectedProductName = '';

    productSelectionHandler(event){
        let recordDetail = event.detail.record;
        this.selectedProductId = recordDetail.Id;
        this.selectedProductId = recordDetail.Name;
    }

    productRemovedHandler(){
        this.selectedProductId = '';
        this.selectedProductId = '';
    }

    selectedVendorId = '';
    selectedVendorName = '';

    vendorSelectionHandler(event){
        let recordDetail = event.detail.record;
        this.selectedVendorId = recordDetail.Id;
        this.selectedVendorName = recordDetail.Name;
    }

    vendorRemovedHandler(){
        this.selectedVendorId = '';
        this.selectedVendorName = '';
    }
    
}