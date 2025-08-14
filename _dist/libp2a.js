"use strict";
var __async = (__this, __arguments, generator) => {
  return new Promise((resolve, reject) => {
    var fulfilled = (value) => {
      try {
        step(generator.next(value));
      } catch (e) {
        reject(e);
      }
    };
    var rejected = (value) => {
      try {
        step(generator.throw(value));
      } catch (e) {
        reject(e);
      }
    };
    var step = (x) => x.done ? resolve(x.value) : Promise.resolve(x.value).then(fulfilled, rejected);
    step((generator = generator.apply(__this, __arguments)).next());
  });
};

// src/config.ts
var BASE_URL = process.env.P2A_BASE_URL || "https://p2a.telescope.chat";

// src/request.ts
var RequestError = class extends Error {
  constructor(status, message) {
    super(`${status}: ${message}`);
  }
};
function request(path, options) {
  return __async(this, null, function* () {
    try {
      const method = options.method;
      const params = options.params;
      const headers = {
        "User-Agent": "@libp2a/libp2a-node",
        "Content-Type": "application/json"
      };
      const body = options.method === "POST" && params ? JSON.stringify(params) : void 0;
      const querystring = options.method === "GET" && params ? new URLSearchParams(params).toString() : void 0;
      const response = yield fetch(`${BASE_URL}${path}?${querystring}`, {
        method,
        body,
        headers
      });
      if (!response.ok) {
        try {
          const rawError = yield response.text();
          throw new RequestError(response.status, rawError);
        } catch (err) {
          if (err instanceof Error) {
            throw new RequestError(response.status, err.message);
          }
          throw new RequestError(response.status, response.statusText);
        }
      }
      return yield response.json();
    } catch (error) {
      if (error instanceof Error) {
        throw new RequestError(500, error.message);
      }
      throw new RequestError(500, "Unknown error");
    }
  });
}

// src/logger.ts
var logger = (message) => {
  console.log(message);
};
function setLogger(newLogger) {
  logger = newLogger;
}
function log(message) {
  logger(message);
}

// src/function.ts
var cachedExecutionPlans = {};
function clearCachedExecutionPlans() {
  Object.keys(cachedExecutionPlans).forEach((key) => {
    delete cachedExecutionPlans[key];
  });
}
function call(staticParts, ...dynamicParts) {
  return __async(this, null, function* () {
    const promptKey = staticParts.join("-");
    log(`Local prompt key generated: ${promptKey}`);
    if (!cachedExecutionPlans[promptKey]) {
      const parts = [];
      for (let i = 0; i < staticParts.length; i++) {
        parts.push({ type: "static", value: staticParts[i] });
        if (i < dynamicParts.length) {
          parts.push({ type: "dynamic", value: dynamicParts[i] });
        }
      }
      log("Building execution plan");
      const executionPlan2 = yield request(
        "/api/v1/function/execution_plans",
        {
          method: "POST",
          params: { parts }
        }
      );
      log(`Execution plan built: ${JSON.stringify(executionPlan2)}`);
      cachedExecutionPlans[promptKey] = executionPlan2;
    }
    const executionPlan = cachedExecutionPlans[promptKey];
    if (!executionPlan) {
      throw new Error(`Execution plan not found for prompt: ${promptKey}`);
    }
    if (executionPlan.steps.length != 1) {
      throw new Error(`Unexpected execution plan with multiple steps`);
    }
    const step = executionPlan.steps[0];
    if (step.type !== "request") {
      throw new Error(`Unexpected step type: ${step.type}`);
    }
    const params = step.params.map((param, index) => [
      param,
      dynamicParts[index]
    ]);
    log(`Sending request to ${step.method} ${step.path}`);
    const data = yield request(step.path, {
      method: step.method,
      params: Object.fromEntries(params)
    });
    log(`Got response: ${JSON.stringify(data)}`);
    return data;
  });
}

// src/index.ts
if (typeof window !== "undefined") {
  window.p2a = {
    call,
    clearCachedExecutionPlans,
    setLogger
  };
}
