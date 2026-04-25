const express = require('express');
const router = express.Router();
const { createReservation, getMesReservations, updateStatut, laisserAvis } = require('../controllers/reservation.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

router.post('/', authMiddleware, createReservation);
router.get('/mes-reservations', authMiddleware, getMesReservations);
router.patch('/:id/statut', authMiddleware, updateStatut);
router.post('/avis', authMiddleware, laisserAvis);

module.exports = router;
