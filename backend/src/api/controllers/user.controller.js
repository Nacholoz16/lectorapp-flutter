const UserService = require('../../services/user.service');

const getProfile = async (req, res, next) => {
    try {
        const { username } = req.params;
        const requestingUserId = req.user.id; // Viene del token (Middleware protect)

        const profile = await UserService.getProfile(username, requestingUserId);
        res.json(profile);
    } catch (error) {
        if (error.message === 'Usuario no encontrado') {
            return res.status(404).json({ error: error.message });
        }
        next(error);
    }
};

const getLibrary = async (req, res, next) => {
    try {
        const { username } = req.params;
        const requestingUserId = req.user.id;
        const page = req.query.page || 1;
        const limit = req.query.limit || 10;

        const library = await UserService.getLibrary(username, requestingUserId, page, limit);
        res.json(library);
    } catch (error) {
        if (error.message === 'Usuario no encontrado') {
            return res.status(404).json({ error: error.message });
        }
        next(error);
    }
};

module.exports = { getProfile, getLibrary };