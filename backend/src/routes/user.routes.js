const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { authMiddleware } = require('../middleware/auth.middleware');

// Mettre à jour son profil
router.put('/profil', authMiddleware, async (req, res) => {
  const { nom, prenom, email, quartier, latitude, longitude } = req.body;
  try {
    const result = await pool.query(
      `UPDATE users SET
         nom = COALESCE($1, nom),
         prenom = COALESCE($2, prenom),
         email = COALESCE($3, email),
         quartier = COALESCE($4, quartier),
         latitude = COALESCE($5, latitude),
         longitude = COALESCE($6, longitude),
         updated_at = CURRENT_TIMESTAMP
       WHERE id = $7 RETURNING id, nom, prenom, email, telephone, role, quartier`,
      [nom, prenom, email, quartier, latitude, longitude, req.user.id]
    );
    res.json({ message: 'Profil mis à jour.', user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
});

module.exports = router;
