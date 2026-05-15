import { LightningElement, api, track } from 'lwc';

export default class MarketingConsentForm extends LightningElement {

    _value = {};

    @api
    get value() { return this._value; }
    set value(val) {
        this._value = val || {};
        this.syncFromValue();
    }

    @api readOnly = false;

 @api
    validate() {
        // 필수 값(이름, 회사, 이메일, 연락처) 중 하나라도 텅 비어있으면 에러 반환
        if (!this.name || !this.company || !this.email || !this.phone) {
            return {
                isValid: false,
                errorMessage: '모든 필수 항목(성함, 회사명, 이메일, 연락처)을 빠짐없이 입력해 주세요.'
            };
        }
        
        // (보너스) 이메일 양식 검사 정규식
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(this.email)) {
            return {
                isValid: false,
                errorMessage: '올바른 이메일 주소 형식을 입력해 주세요. (예: user@example.com)'
            };
        }
        // 모든 조건이 완벽하면 프레임워크에 제출 승인!
        return { isValid: true };
    }
    
    @track name           = '';
    @track title           = '';
    @track company        = '';
    @track email          = '';
    @track phone          = '';
    @track marketingAgree = 'agree';

    get isAgree()    { return this.marketingAgree === 'agree'; }
    get isDisagree() { return this.marketingAgree === 'disagree'; }

    syncFromValue() {
        if (this._value) {
            this.name           = this._value.name           || '';
            this.company        = this._value.company        || '';
            this.title        = this._value.title        || '';
            this.email          = this._value.email          || '';
            this.phone          = this._value.phone          || '';
            this.marketingAgree = this._value.marketingAgree || null;
        }
    }

    handleInput(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
        this.dispatchValueChange();
    }

    handleMarketingChange(event) {
        this.marketingAgree = event.target.value;
        this.dispatchValueChange();
    }

    // ✅ 입력값 변경 시마다 Agent 플래너에 전달
    // Standard Submit 클릭 시 최종 value로 Apex InvocableMethod 실행
    dispatchValueChange() {
        this.dispatchEvent(new CustomEvent('valuechange', {
            detail: {
                value: {
                    name:           this.name,
                    company:        this.company,
                    email:          this.email,
                    phone:          this.phone,
                    title:          this.title,
                    marketingAgree: this.marketingAgree
                }
            }
        }));
    }
}
