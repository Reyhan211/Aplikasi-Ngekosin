class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/** Bungkus handler async agar error masuk ke error middleware. */
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

/** Format respons sukses: { success: true, data } */
const ok = (res, data = null, status = 200) => res.status(status).json({ success: true, data });

const toInt = (v) => {
  const n = Number(v);
  return Number.isInteger(n) ? n : NaN;
};

/** Ambil id dari parameter URL, atau lempar 400. */
const idParam = (req, name = 'id') => {
  const n = toInt(req.params[name]);
  if (!(n > 0)) throw new HttpError(400, 'ID tidak valid');
  return n;
};

module.exports = { HttpError, wrap, ok, toInt, idParam };
