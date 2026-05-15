const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

// Inscription
const register = async (req, res) => {
  const { nom, prenom, email, telephone, mot_de_passe, role, quartier } = req.body;

  // Validation
  if (!nom || !prenom || !telephone || !mot_de_passe || !role) {
    return res.status(400).json({ message: 'Champs obligatoires manquants.' });
  }
  if (!['client', 'prestataire'].includes(role)) {
    return res.status(400).json({ message: 'Rôle invalide. Choisir : client ou prestataire.' });
  }

  try {
    // Vérifier si le téléphone existe déjà
    const existing = await pool.query(
      'SELECT id FROM users WHERE telephone = $1',
      [telephone]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({ message: 'Ce numéro de téléphone est déjà utilisé.' });
    }

    // Hasher le mot de passe
    const hash = await bcrypt.hash(mot_de_passe, 10);

    // Créer l'utilisateur
    const result = await pool.query(
      `INSERT INTO users (nom, prenom, email, telephone, mot_de_passe, role, quartier)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, nom, prenom, telephone, role`,
      [nom, prenom, email || null, telephone, hash, role, quartier || null]
    );

    const user = result.rows[0];

    // Générer le token JWT
    const token = jwt.sign(
      { id: user.id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    res.status(201).json({
      message: 'Inscription réussie !',
      token,
      user: {
        id: user.id,
        nom: user.nom,
        prenom: user.prenom,
        telephone: user.telephone,
        role: user.role
      }
    });
  } catch (err) {
    console.error('Erreur register:', err.message);
    res.status(500).json({ message: 'Erreur lors de l\'inscription.' });
  }
};

// Connexion
const login = async (req, res) => {
  const { telephone, mot_de_passe } = req.body;

  if (!telephone || !mot_de_passe) {
    return res.status(400).json({ message: 'Téléphone et mot de passe requis.' });
  }

  try {
    const result = await pool.query(
      'SELECT * FROM users WHERE telephone = $1 AND est_actif = TRUE',
      [telephone]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ message: 'Numéro ou mot de passe incorrect.' });
    }

    const user = result.rows[0];
    const validPassword = await bcrypt.compare(mot_de_passe, user.mot_de_passe);

    if (!validPassword) {
      return res.status(401).json({ message: 'Numéro ou mot de passe incorrect.' });
    }

    const token = jwt.sign(
      { id: user.id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    res.json({
      message: 'Connexion réussie !',
      token,
      user: {
        id: user.id,
        nom: user.nom,
        prenom: user.prenom,
        telephone: user.telephone,
        role: user.role,
        quartier: user.quartier,
        note_moyenne: user.note_moyenne
      }
    });
  } catch (err) {
    console.error('Erreur login:', err.message);
    res.status(500).json({ message: 'Erreur lors de la connexion.' });
  }
};

// Profil connecté
const getMe = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, nom, prenom, email, telephone, role, quartier, ville, photo_url, latitude, longitude, note_moyenne, nombre_avis, est_verifie, created_at FROM users WHERE id = $1',
      [req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Utilisateur non trouvé.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

module.exports = { register, login, getMe };
