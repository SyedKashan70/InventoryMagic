/**
 * @description       : 
 * @author            : Syed Kashan
 * @group             : 
 * @last modified on  : 06-05-2025
 * @last modified by  : Syed Kashan
**/
import { LightningElement ,track} from 'lwc';
import getStockingLocations from '@salesforce/apex/offlineController.getStockingLocations';
import getWareHouses from '@salesforce/apex/offlineController.getWareHouses';
import getCustomerAccounts from '@salesforce/apex/offlineController.getCustomerAccounts';
import getActiveProducts from '@salesforce/apex/offlineController.getActiveProducts';
import createOrderandOrderProduct from '@salesforce/apex/offlineController.createOrderandOrderProduct';
import createQuoteandQuoteLines from '@salesforce/apex/offlineController.createQuoteandQuoteLines';
import getOrderItemsToReserve from '@salesforce/apex/offlineController.getOrderItemsToReserve';
import getInventoryDetailList from '@salesforce/apex/offlineController.getInventoryDetailList';
import getInventory from '@salesforce/apex/offlineController.getInventory';
import reservedOrderProduct from '@salesforce/apex/offlineController.reservedOrderProduct';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class OfflineCmp extends LightningElement {

    @track customerAccounts = [];
    @track products = [];
    @track stockingLocations = [];
    @track wareHouse = [];
    @track orderItemToReserve = [];
    @track inventory = [];
    @track isLoading = false;
    @track isOnline = navigator.onLine;
    @track lastSynced = localStorage.getItem('lastSynced');
    currentView = 'main';
    cacheRecordList = [];
    recordListViewObj = '';



    connectedCallback() {
        window.addEventListener('online', this.handleOnline.bind(this));
        window.addEventListener('offline', this.handleOffline.bind(this));
        this.loadData();
    }

    disconnectedCallback() {
        window.removeEventListener('online', this.handleOnline.bind(this));
        window.removeEventListener('offline', this.handleOffline.bind(this));
    }

    get customerAccountSize() {
        return this.customerAccounts.length;
    }

    get productsSize() {
        return this.products.length;
    }
    
    get stockingLocationsSize() {
        return this.stockingLocations.length;
    }

    get wareHouseSize() {
        return this.wareHouse.length;
    }

    get isMainView() {
        return this.currentView == 'main';
    }
    
    get isOrderView() {
        return this.currentView == 'order';
    }

    get isQuoteView() {
        return this.currentView == 'quote';
    }

    get isRecordLstView(){
        return this.currentView == 'listView';
    }

    get isReserveOrderView(){
        return this.currentView == 'reserveOrder';
    }
    
    get orderSize(){
        let cachedOrders = JSON.parse(localStorage.getItem('cachedOfflineOrders')) || [];
        let cachedOrdersSize = cachedOrders.length || 0;
        return cachedOrdersSize;
    }

    get quoteSize(){
        let cachedQuotes = JSON.parse(localStorage.getItem('cachedOfflineQuotes')) || [];
        let cachedQuotesSize = cachedQuotes.length || 0;
        return cachedQuotesSize;
    }

    get orderItemToReserveSize() {
        return this.orderItemToReserve.length;
    }

    get internetStatus(){
        if (navigator.onLine) {
            return 'Online';
        } else {
            return 'Offline';
        }
    }

    handleOnline() {
        this.isOnline = true;
        this.syncFromServer();
    }

    handleOffline() {
        this.isOnline = false;
    }

    loadData() {
        if (this.isOnline) {
            this.syncFromServer();
        }
    }

    async syncFromServer() {
        
        await this.syncOfflineOrders();
        await this.syncOfflineQuotes();
        await this.syncOfflineReserveOrder();
        this.isLoading = true;
        await new Promise(resolve => setTimeout(resolve, 300)); 
    
        await Promise.all([
            this.syncCustomerAccounts(),
            this.syncProducts(),
            this.syncStockingLocation(),
            this.syncInventory(),
            this.syncWarehouse(),
            this.syncOrderItemToReserve()
        ]);
    
        // Update last sync timestamp after all syncs are done
        this.updateLastSync();
    
        // Turn off loading spinner once all tasks are complete
        this.isLoading = false;
    }

    handleSync(){
        this.syncFromServer();
    }
    

    updateLastSync() {
        const now = new Date().toLocaleString();
        this.lastSynced = now;
        localStorage.setItem('lastSynced', now);
    }

    async syncCustomerAccounts() {
        try {
            const result = await getCustomerAccounts();
            this.customerAccounts = result;
            localStorage.setItem('cachedCustomerAccounts', JSON.stringify(result))
        } catch (error) {
            console.error('Error fetching customer accounts:', error);
            this.loadCustomerAccounts();
        }
    }

    async syncProducts() {
        try {
            const result = await getActiveProducts();
            this.products = result;
            localStorage.setItem('cachedProducts', JSON.stringify(result));

            const inventoryIds = [];

            result.forEach(product => {
                if (product.Id) {
                    inventoryIds.push(product.invId);
                }
            });
            console.log('inventoryIds :: '+JSON.stringify(inventoryIds));
            getInventoryDetailList({ invIds: inventoryIds })
            .then(data => {
                console.log('data :: '+JSON.stringify(data));
                localStorage.setItem('cachedInventoryDetail', JSON.stringify(data));  
            })
            .catch(error => {
                console.error('Error retrieving inventory details:', error);
            });

        } catch (error) {
            console.error('Error fetching products:', error);
            this.loadProducts();
        }
    }

    async syncOrderItemToReserve() {
        try {
            const result = await getOrderItemsToReserve();
            this.orderItemToReserve = result;
            localStorage.setItem('cachedorderItemToReserve', JSON.stringify(result))
        } catch (error) {
            console.error('Error fetching orderItemToReserve:', error);
            this.loadOrderItemsToReserve();
        }
    }

    async syncInventory() {
        try {
            const result = await getInventory();
            this.inventory = result;
            localStorage.setItem('cachedInventory', JSON.stringify(result))
        } catch (error) {
            console.error('Error fetching inventory:', error);
            this.loadInventory();
        }
    }

    loadInventory() {
        const cached = localStorage.getItem('cachedInventory');
        this.inventory = cached ? JSON.parse(cached) : [];
    }


    loadCustomerAccounts() {
        const cached = localStorage.getItem('cachedCustomerAccounts');
        this.customerAccounts = cached ? JSON.parse(cached) : [];
    }

    loadOrderItemsToReserve() {
        const cached = localStorage.getItem('cachedorderItemToReserve');
        this.orderItemToReserve = cached ? JSON.parse(cached) : [];
    }

    loadProducts() {
        const cached = localStorage.getItem('cachedProducts');
        this.products = cached ? JSON.parse(cached).filter(p => p.IsActive) : [];
    }




    async syncStockingLocation() {
        try {
            const result = await getStockingLocations();
            this.stockingLocations = result;
            localStorage.setItem('cachedStockingLocations', JSON.stringify(result));
        } catch (error) {
            console.error('Error fetching stocking location', error);
            this.loadStockingLocations();
        }
    }

    loadStockingLocations() {
        const cached = localStorage.getItem('cachedStockingLocations');
        this.stockingLocations = cached ? JSON.parse(cached) : [];
    }


    async syncWarehouse() {
        try {
            const result = await getWareHouses();
            this.wareHouse = result;
            localStorage.setItem('cachedWarehouse', JSON.stringify(result));
        } catch (error) {
            console.error('Error fetching warehouse:', error);
            this.loadWarehouse();
        }
    }

    loadWarehouse() {
        const cached = localStorage.getItem('cachedWarehouse');
        this.wareHouse = cached ? JSON.parse(cached) : [];
    }

    
    async syncOfflineOrders() {
        const cachedOrders = JSON.parse(localStorage.getItem('cachedOfflineOrders')) || [];
        if (cachedOrders.length == 0) return;
        this.isLoading = true;
        try {
            createOrderandOrderProduct({ cachedOrders: cachedOrders })
            .then(result => {
                localStorage.setItem('cachedOfflineOrders', JSON.stringify([]));
                localStorage.removeItem('cachedOfflineOrders');
                this.isLoading = false;
                this.showToast('Success',result, 'success');
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body.message || 'An error occurred', 'error');
            });
        } catch (err) {
            console.error('Error syncing offline orders:'+JSON.stringify(err));
            this.isLoading = false;
        }
    }

    async syncOfflineQuotes() {
        const cachedQuotes = JSON.parse(localStorage.getItem('cachedOfflineQuotes')) || [];
        if (cachedQuotes.length == 0) return;
        this.isLoading = true;
        try {
            createQuoteandQuoteLines({ cachedQuotes: cachedQuotes })
            .then(result => {
                localStorage.setItem('cachedOfflineQuotes', JSON.stringify([]));
                localStorage.removeItem('cachedOfflineQuotes');
                this.isLoading = false;
                this.showToast('Success',result, 'success');
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body.message || 'An error occurred', 'error');
            });
        } catch (err) {
            console.error('Error syncing offline quotes:'+JSON.stringify(err));
            this.isLoading = false;
        }
    }

    async syncOfflineReserveOrder() {
        const allOrderLines = JSON.parse(localStorage.getItem('cachedorderItemToReserve')) || [];
        const invLines = JSON.parse(localStorage.getItem('cachedInventory')) || [];

        // Filter only those with quantityReserved > 0
        const OrderLines = allOrderLines.filter(item => Number(item.quantityReserved) > 0);
        console.log('OrderLines.lengt :: '+OrderLines.length);
        if (OrderLines.length == 0) {
            console.log('No OrderLines to sync');
            return;
        }
        this.isLoading = true;
        try {
            reservedOrderProduct({ OrderLines: OrderLines,invLines: invLines })
            .then(result => {
                localStorage.setItem('cachedorderItemToReserve', JSON.stringify([]));
                localStorage.removeItem('cachedorderItemToReserve');
                this.isLoading = false;
                this.showToast('Success',result, 'success');
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body.message || 'An error occurred', 'error');
            });
        } catch (err) {
            console.error('Error syncing offline orders:'+JSON.stringify(err));
            this.isLoading = false;
        }
    }

    
    handleCreateOrderClick(){
        this.currentView = 'order';
    }

    handleCreateQuoteClick(){
        this.currentView = 'quote';
    }

    handleReserveOrderClick(){
        this.currentView = 'reserveOrder';
    }
    
    handleChildCancel() {
        this.currentView = 'main';
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }

    handleItemClick(event){
        let objName = event.currentTarget.dataset.obj;
        let cacheRecordName = event.currentTarget.dataset.cache;
        
        this.recordListViewObj = objName;
        this.cacheRecordList = JSON.parse(localStorage.getItem(cacheRecordName)) || [];
        this.currentView = 'listView';
    }

    handleBack(){
        this.currentView = 'main';
        this.recordListViewObj = '';
        this.cacheRecordList = [];
    }
}