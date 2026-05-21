import { LightningElement, api } from 'lwc';

const STOP_WORDS = new Set([
    'the', 'a', 'an', 'is', 'was', 'are', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'shall',
    'should', 'may', 'might', 'must', 'can', 'could', 'of', 'in', 'to',
    'for', 'with', 'on', 'at', 'from', 'by', 'about', 'as', 'into',
    'through', 'during', 'before', 'after', 'and', 'but', 'or', 'nor',
    'not', 'so', 'yet', 'both', 'either', 'neither', 'each', 'every',
    'this', 'that', 'these', 'those', 'it', 'its', 'i', 'me', 'my',
    'we', 'our', 'you', 'your', 'he', 'she', 'they', 'them', 'their',
    'what', 'which', 'who', 'whom', 'there', 'here', 'when', 'where',
    'why', 'how', 'any', 'some', 'no', 'all', 'if', 'then', 'than'
]);

const TYPING_SPEED_MS = 12;

export default class EciCallExplorer extends LightningElement {
    @api callTitle = '';
    @api transcriptData = [];
    @api explorerQaData = [];
    @api summaryData = {};

    _conversation = [];
    _msgCounter = 0;
    _minimized = false;
    currentQuestion = '';
    _typingInterval = null;
    _activeAnswerIdx = -1;

    get dialogClass() {
        return this._minimized ? 'explorer-dialog minimized' : 'explorer-dialog';
    }

    get isExpanded() {
        return !this._minimized;
    }

    get minimizeIcon() {
        return this._minimized ? 'utility:chevronup' : 'utility:dash';
    }

    get hasConversation() {
        return this._conversation.length > 0;
    }

    get showSuggestions() {
        return !this.hasConversation;
    }

    get showAskAnother() {
        return this.hasConversation && !this.isTypingAnswer && this._activeAnswerIdx === -1;
    }

    get isTypingAnswer() {
        return this._activeAnswerIdx >= 0;
    }

    get isSendDisabled() {
        return !this.currentQuestion || this.currentQuestion.trim().length === 0;
    }

    get conversationHistory() {
        return this._conversation.map((msg, idx) => ({
            ...msg,
            id: `msg-${idx}`,
            cssClass: msg.isQuestion ? 'message message-question' : 'message message-answer',
            isComplete: !msg.isQuestion && idx !== this._activeAnswerIdx
        }));
    }

    get suggestedQuestions() {
        const qa = this.explorerQaData || [];
        const suggestions = qa.slice(0, 5).map((item, idx) => ({
            id: `sq-${idx}`,
            text: item.question
        }));
        return suggestions;
    }

    handleMinimize() {
        this._minimized = !this._minimized;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleInput(event) {
        this.currentQuestion = event.target.value;
    }

    handleKeyUp(event) {
        if (event.key === 'Enter' && this.currentQuestion.trim()) {
            this.handleSend();
        }
    }

    handleSend() {
        const question = this.currentQuestion.trim();
        if (!question) return;
        this.currentQuestion = '';
        this._submitQuestion(question);
    }

    handleSuggestionClick(event) {
        const question = event.currentTarget.dataset.question;
        this._submitQuestion(question);
    }

    handleAskAnother() {
        this.currentQuestion = '';
        this._conversation = [];
        this._activeAnswerIdx = -1;
    }

    _submitQuestion(question) {
        this._conversation = [
            ...this._conversation,
            { isQuestion: true, text: question, displayText: question }
        ];

        const answer = this._findAnswer(question);

        const answerIdx = this._conversation.length;
        this._conversation = [
            ...this._conversation,
            { isQuestion: false, text: answer, displayText: '' }
        ];
        this._activeAnswerIdx = answerIdx;

        this._scrollToBottom();
        this._startTypingAnimation(answerIdx, answer);
    }

    _findAnswer(question) {
        const tokens = this._tokenize(question);

        const qa = this.explorerQaData || [];
        let bestScore = 0;
        let bestAnswer = '';

        for (const item of qa) {
            let score = 0;
            const kw = (item.keywords || []).map(k => k.toLowerCase());

            for (const token of tokens) {
                if (kw.includes(token)) {
                    score += 3;
                }
            }

            const qTokens = this._tokenize(item.question);
            for (const token of tokens) {
                if (qTokens.includes(token)) {
                    score += 2;
                }
            }

            if (score > bestScore) {
                bestScore = score;
                bestAnswer = item.answer;
            }
        }

        if (bestScore >= 2) {
            return bestAnswer;
        }

        return this._searchTranscript(tokens);
    }

    _searchTranscript(tokens) {
        const entries = this.transcriptData || [];
        const scored = entries.map((entry, idx) => {
            const entryTokens = this._tokenize(entry.text || '');
            let score = 0;
            for (const t of tokens) {
                if (entryTokens.includes(t)) score++;
            }
            return { idx, score, entry };
        });

        scored.sort((a, b) => b.score - a.score);
        const top = scored.filter(s => s.score > 0).slice(0, 3);

        if (top.length === 0) {
            return 'I wasn\'t able to find specific information about that in this conversation. Try asking about the products discussed, next steps, customer sentiment, or objections raised.';
        }

        let result = 'Based on the conversation, ';
        const excerpts = top.map(s => {
            const speaker = s.entry.speaker === 'customer' ? 'the customer' : 'the rep';
            const text = (s.entry.text || '').length > 200
                ? s.entry.text.substring(0, 200) + '...'
                : s.entry.text;
            return speaker + ' mentioned: "' + text + '"';
        });
        result += excerpts.join('. Additionally, ') + '.';
        return result;
    }

    _tokenize(text) {
        return text
            .toLowerCase()
            .replace(/[^a-z0-9\s-]/g, '')
            .split(/\s+/)
            .filter(t => t.length > 1 && !STOP_WORDS.has(t));
    }

    _startTypingAnimation(answerIdx, fullText) {
        let charIdx = 0;

        if (this._typingInterval) {
            clearInterval(this._typingInterval);
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._typingInterval = setInterval(() => {
            charIdx += 2;
            if (charIdx >= fullText.length) {
                charIdx = fullText.length;
                clearInterval(this._typingInterval);
                this._typingInterval = null;
                this._activeAnswerIdx = -1;
            }

            const updated = [...this._conversation];
            updated[answerIdx] = {
                ...updated[answerIdx],
                displayText: fullText.substring(0, charIdx)
            };
            this._conversation = updated;

            this._scrollToBottom();
        }, TYPING_SPEED_MS);
    }

    _scrollToBottom() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const area = this.template.querySelector('.conversation-area');
            if (area) {
                area.scrollTop = area.scrollHeight;
            }
        }, 0);
    }

    disconnectedCallback() {
        if (this._typingInterval) {
            clearInterval(this._typingInterval);
        }
    }
}
