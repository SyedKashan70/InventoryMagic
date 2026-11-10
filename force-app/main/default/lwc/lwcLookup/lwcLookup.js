import {
    LightningElement,
    track,
    wire,
    api
} from "lwc";
import findRecordsWithFilters from "@salesforce/apex/LwcLookupController.findRecordsWithFilters";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class LwcLookup extends LightningElement {

    @track recordsList;
    @track searchKey = "";
    @api parentId;
    @api selectedValue;
    @api selectedRecordId;
    @api objectApiName;
    @api objectLabel;
    @api iconName;
    @api helpText;
    @api lookupPlaceholder = 'Search...';

    @api selectedLabelName = "Name"; //Assign Label to show after lookup selection
    @api selectedValueName = "Id"; //Assign Value to show after lookup selection

    /*Dynamic lookup parameters */
    @api isCreatable = false;
    @api isEditable = false;
    @api showSearchIcon = false;
    @api queryFields;
    @api queryFilters;
    @api orderByFieldsWithOrder;
    @api recordLimit;
    @api searchFromStart = false; //if true it will search the word from the start; on false it will search key from whole string
     
    @api lookupLabel;
    @api blockChangeRecord = false; //true will hide cancel icon from lookup
    @api isDisable = false;

    @api filterIds = []; // Only filters the provided ids

    @track message;
    showOptions = false;

    get editableAllowed() {
        return !this.blockChangeRecord && this.isEditable;
    }

    get editLinkLabel() {
        return "Edit " + this.selectedValue;
    }


    /*Handle On leave */
    onLeave(event) {
        setTimeout(() => {
            //this.recordsList = null;  
            this.showOptions = false;
        }, 300);
    }

    /*Handle record selection fire when record is selected*/
    recordSelection(event) {
        let rowNum = event.target.dataset.id;
        this.selectedRecordId = event.target.dataset.key;
        this.selectedValue = event.target.dataset.name;
        this.seletedRecordUpdate(rowNum);
    }

    /*Handle foucs of lookup*/
    handleonfocus(event) {
        this.showOptions = true;
    }

    handleKeyChange(event) {
        const searchKey = event.target.value;
        this.searchKey = searchKey;
    }

    removeRecordOnLookup(event) {
        this.searchKey = "";
        this.selectedValue = null;
        this.selectedRecordId = null;
        // this.recordsList = null;
        let parentId = this.parentId;

        const removeEvent = new CustomEvent('recordremoved');
        this.dispatchEvent(removeEvent);
    }
    /*findRecordsWithFilters takes search key object name fields of object query filters eg recordtype as parameter
    and return records and error
    */ 
    @wire(findRecordsWithFilters, {
        searchKey: '$searchKey',
        objectName: '$objectApiName',
        queryFields: '$queryFields',
        queryFilters: '$queryFilters',
        orderByFieldsWithOrder: '$orderByFieldsWithOrder',
        recordLimit: '$recordLimit',
        searchFromStart: '$searchFromStart',
        wildCard: '$selectedLabelName'
        // filterIds: '$filterIds'
    })
    wiredResuts({
        error,
        data
    }) {
        let result = data;
        if (result) {
             
            if (result.length === 0) {
                this.recordsList = [];
                this.message = "No Records Found";
            } else {
                let tempArray = [];
                if (this.objectApiName == 'D_Product_Line__c') {
                    result.forEach((ele, i) => {
                        tempArray.push({
                            // Id: ele.Id,
                            // Name: ele.Name,
                            Id: ele[this.selectedValueName],
                            Name: ele[this.selectedLabelName],
                            recordDetail: ele,
                            RowIndex: i
                        })
                    });
                    this.recordsList = tempArray;
                    this.message = "";
                } else if (this.objectApiName == 'Product2') {
                    result.forEach((ele, i) => {

                        tempArray.push({
                            // Id: ele.Id,
                            // Name: ele.Name,
                            Id: ele[this.selectedValueName],
                            Name: ele[this.selectedLabelName],
                            RegistryGroupId: ele?.D_Service_NDIS_Registry_Group__c,
                            RegistryGroupName: ele?.D_Service_NDIS_Registry_Group__r?.Name,
                            SupportCategoryId: ele?.D_Service_NDIS_Support_Category__c,
                            SupportCategoryName: ele?.D_Service_NDIS_Support_Category__r?.Name,
                            ProductName: ele?.D_Service_Product_Lookup__r?.Name,
                            ProductId: ele?.D_Service_Product_Lookup__c,
                            serviceId: ele?.D_Service_Product_Lookup__r?.D_Product_Line__c,
                            serviceName: ele?.D_Service_Product_Lookup__r?.D_Product_Line__r?.Name,
                            pricebookEditable: ele?.D_Pricebook_Editable_Service__c ? ele?.D_Pricebook_Editable_Service__c : false,
                            QuantityUnitOfMeasure: ele?.QuantityUnitOfMeasure,
                            recordDetail: ele,
                            RowIndex: i
                        })
                    });
                    this.recordsList = tempArray;
                    this.message = "";
                } else {
                    result.forEach((ele, i) => {
                        tempArray.push({
                            recordDetail: ele,
                            // Id: ele.Id,
                            // Name: ele.Name,
                            Id: ele[this.selectedValueName],
                            Name: ele[this.selectedLabelName],
                            RowIndex: i
                        })
                    });
                    this.recordsList = tempArray;
                    this.message = "";
                }
            }
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.showErrorMessage(error.body.message);
            this.recordsList = undefined;
        }
    }

    seletedRecordUpdate(row) {
        let tempObj = this.recordsList[row];
        if (this.objectApiName == 'Product2') {
            const passEventr = new CustomEvent('recordselection', {
                detail: {
                    record: tempObj
                }
            });
            this.dispatchEvent(passEventr);
        } else {
            const passEventr = new CustomEvent('recordselection', {
                detail: {
                    record: tempObj.recordDetail
                }
            });
            this.dispatchEvent(passEventr);
        }
    }

    AddNewClickHandler(event) {
        const passEventr = new CustomEvent('addnewclicked');
        this.dispatchEvent(passEventr);
    }

    SearchIconClickHandler(event) {
        const passEventr = new CustomEvent('searchiconclicked');
        this.dispatchEvent(passEventr);
    }

    editRecordClickHandler(event) {
        const passEventr = new CustomEvent('editrecordclicked', {
            detail: {
                Id: this.selectedRecordId,
                Name: this.selectedValue
            }
        });
        this.dispatchEvent(passEventr);
    }


    showErrorMessage(errorMessage){
        const evt = new ShowToastEvent({
            title: 'Error',
            message: errorMessage,
            variant: 'Error',
            mode:'dismissable'
        });
        this.dispatchEvent(evt);
    }

}