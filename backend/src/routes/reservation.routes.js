const express = require('express');
const router = express.Router();
const {
  createReservation,
  getMesReservations,
  updateStatut,
  laisserAvis,
  updateStatutPaiement,
  simulerPaiement
} = require('../controllers/reservation.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

router.post('/', authMiddleware, createReservation);
router.get('/mes-reservations', authMiddleware, getMesReservations);
router.patch('/:id/statut', authMiddleware, updateStatut);
router.patch('/:id/paiement', authMiddleware, updateStatutPaiement);
router.post('/:id/simuler-paiement', authMiddleware, simulerPaiement);
router.post('/avis', authMiddleware, laisserAvis);

module.exports = router;
