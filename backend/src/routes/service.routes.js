const express = require('express');
const router = express.Router();
const {
  getCategories,
  getPrestataires,
  getPrestataire,
  createService,
  uploadServiceImage
} = require('../controllers/service.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

router.get('/categories', getCategories);
router.get('/prestataires', getPrestataires);
router.get('/prestataires/:id', getPrestataire);
router.post('/', authMiddleware, uploadServiceImage, createService);

module.exports = router;
