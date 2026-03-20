const cache = require("../utils/cache");

module.exports = async function (fastify, opts) {
  fastify.post("/admin/clear-cache", async (request, reply) => {
    const secretKey = process.env.SECRET_KEY;

    // Only allow authorized K8s CronJobs to clear this globally.
    // Fail closed if the secret is missing so the endpoint never becomes public.
    if (!secretKey || request.headers.authorization !== secretKey) {
      reply.code(403);
      return { error: "Forbidden: Invalid Secret" };
    }

    cache.reset();
    request.log.warn({ action: 'cache_clear', ip: request.ip }, 'admin cache reset')
    return { success: true, message: "Fastify memory cache successfully reset" };
  });
};
