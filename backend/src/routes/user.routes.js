const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const router = express.Router();
const pool = require('../config/db');
const { authMiddleware } = require('../middleware/auth.middleware');

const profileUploadDir = path.join(__dirname, '../../uploads/profiles');
fs.mkdirSync(profileUploadDir, { recursive: true });

const profileStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, profileUploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase() || '.jpg';
    cb(null, `profile-${req.user.id}-${Date.now()}${ext}`);
  }
});

const uploadProfilePhoto = multer({
  storage: profileStorage,
  fileFilter: (req, file, cb) => {
    if (!file.mimetype || !file.mimetype.startsWith('image/')) {
      return cb(new Error('Le fichier doit être une image.'));
    }
    cb(null, true);
  },
  limits: { fileSize: 5 * 1024 * 1024 }
}).single('photo');

const userSelectFields = `id, nom, prenom, email, telephone, role, photo_url, quartier, ville,
  latitude, longitude, note_moyenne, nombre_avis, est_verifie`;

// Mettre à jour son profil (+ photo optionnelle)
router.put('/profil', authMiddleware, (req, res, next) => {
  uploadProfilePhoto(req, res, (err) => {
    if (err) return res.status(400).json({ message: err.message || 'Erreur upload.' });
    next();
  });
}, async (req, res) => {
  const { nom, prenom, email, quartier, latitude, longitude } = req.body;
  const photoUrl = req.file ? `/uploads/profiles/${req.file.filename}` : null;
  try {
    const result = await pool.query(
      `UPDATE users SET
         nom = COALESCE(NULLIF($1, ''), nom),
         prenom = COALESCE(NULLIF($2, ''), prenom),
         email = COALESCE($3, email),
         quartier = COALESCE($4, quartier),
         latitude = COALESCE($5, latitude),
         longitude = COALESCE($6, longitude),
         photo_url = COALESCE($7, photo_url),
         updated_at = CURRENT_TIMESTAMP
       WHERE id = $8 RETURNING ${userSelectFields}`,
      [nom, prenom, email || null, quartier || null, latitude || null, longitude || null, photoUrl, req.user.id]
    );
    res.json({ message: 'Profil mis à jour.', user: result.rows[0] });
  } catch (err) {
    console.error('Erreur update profil:', err.message);
    res.status(500).json({ message: 'Erreur serveur.' });
  }
});

module.exports = router;
