import { LightningElement } from 'lwc';

export default class DashboardApp extends LightningElement {
    selectedComponent = 'home'; // default view

    get isHome() {
        return this.selectedComponent === 'home';
    }
    get isOrderReserved() {
        return this.selectedComponent === 'orderReserved';
    }
    get isOrderUnreserved() {
        return this.selectedComponent === 'orderUnreserved';
    }
    get isReceivePo() {
        return this.selectedComponent === 'receivePo';
    }
    get isMagicTransfer() {
        return this.selectedComponent === 'magicTransfer';
    }
    get isCreateInvoice() {
        return this.selectedComponent === 'createInvoice';
    }
    get isStockTransfer() {
        return this.selectedComponent === 'stockTransfer';
    }
    get isStockAdjustment() {
        return this.selectedComponent === 'stockAdjustment';
    }

    handleMenuClick(event) {
        this.selectedComponent = event.currentTarget.dataset.key;
    }
}