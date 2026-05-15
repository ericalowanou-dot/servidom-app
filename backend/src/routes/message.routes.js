const express = require('express');
const router = express.Router();
const { getMesConversations, getMessages, sendMessage } = require('../controllers/message.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

router.use(authMiddleware);

router.get('/conversations', getMesConversations);
router.get('/reservation/:reservationId', getMessages);
router.post('/', sendMessage);

module.exports = router;
