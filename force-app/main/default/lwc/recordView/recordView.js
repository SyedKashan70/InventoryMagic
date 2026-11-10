import { LightningElement,api } from 'lwc';

export default class RecordView extends LightningElement {
    @api label;         // e.g., 'Accounts'
    @api count;         // e.g., 890
    @api iconName;      // e.g., 'standard:account'
    @api color;         // e.g., '#5A55FF'

    get formattedCount() {
        return this.count > 999 ? (this.count / 1000).toFixed(1) + 'k' : this.count;
    }

    get iconStyle() {
        return `background-color: ${this.color}; border-radius: 8px; padding: 6px;`;
    }

    handleClick() {
        this.dispatchEvent(new CustomEvent('itemclick', {
            detail: { label: this.label }
        }));
    }
}