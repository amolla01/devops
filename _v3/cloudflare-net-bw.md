
To forward a single call to both Dallas and Dhaka for simultaneous processing while utilizing a delayed Kafka/Queue flow, you use [Cloudflare Load Balancing](https://www.cloudflare.com/products/load-balancing/) combined with [Cloudflare Workers](https://developers.cloudflare.com/queues/) and Cloudflare Queues. [1, 2, 3] 
Here is a step-by-step breakdown of how to build this exact architecture:
## 1. Ingest & Duplicate the Request
When an API call reaches Cloudflare's Edge, a single Cloudflare Worker acts as your traffic controller. Instead of choosing just one destination, the Worker captures the raw incoming request and duplicates the payload (the data inside the call). [3] 
## 2. Immediate Forwarding (Dallas)
The Worker uses the [Fetch API](https://developers.cloudflare.com/workers/runtime-apis/fetch/) to immediately forward the first copy of the call to your Dallas backend. It waits for the Dallas server to do its partial processing and sends that result back to the user without delay. [3] 
## 3. Asynchronous Forwarding (Dhaka)
In the background, the Worker sends a second copy of the request to your Dhaka backend. It does this asynchronously so the user doesn’t have to wait for Dhaka to respond.
## 4. Delayed Processing via Cloudflare Queues
Instead of directly pushing the Dhaka processing into a Kafka cluster over the public internet, the Worker sends the data to Cloudflare Queues. Cloudflare Queues acts like a temporary waiting room that guarantees the data is safely stored without dropping the message. [2, 3] 
## 5. Consuming for Dallas
Finally, your Dallas infrastructure consumes the data from your Cloudflare Queue using either a [pull consumer over HTTP](https://developers.cloudflare.com/queues/reference/how-queues-works/) or a [consumer Worker](https://developers.cloudflare.com/queues/get-started/) that securely routes data to your private Kafka. [2, 4, 5] 
------------------------------
If you want, I can help you:

* Estimate the cost for both the Edge Workers and Queues.
* Write a sample JavaScript script to duplicate the request.
* Set up retry limits if Dhaka is temporarily offline.

Let me know how you would like to proceed!

[1] [https://www.cloudflare.com](https://www.cloudflare.com/products/load-balancing/)
[2] [https://developers.cloudflare.com](https://developers.cloudflare.com/queues/reference/how-queues-works/)
[3] [https://blog.cloudflare.com](https://blog.cloudflare.com/introducing-cloudflare-queues/)
[4] [https://blog.cloudflare.com](https://blog.cloudflare.com/messages-at-your-speed-with-concurrency-and-explicit-acknowledgement/)
[5] [https://blog.cloudflare.com](https://blog.cloudflare.com/messages-at-your-speed-with-concurrency-and-explicit-acknowledgement/)



Cloudflare's cost model is based strictly on usage volume. There are zero data transfer or bandwidth egress fees. [1, 2, 3, 4] 
To estimate costs accurately, calculations are broken down per 10 million incoming API requests (assuming payload sizes under 64 KB). [2, 3] 
## 1. Cost Drivers per Component [5] 
A single client request triggers multiple operations across your architecture:

* Worker Invocations: 2 total (1 for the Initial Ingestion Worker + 1 for the Dhaka Queue Consumer Worker).
* Queue Operations: 3 total (1 Write to the queue + 1 Read by the consumer + 1 Delete after successful delivery). [1, 2, 6] 

------------------------------
## 2. Pricing Tiers (Workers Paid Plan) [7] 
The [Cloudflare Workers Paid Plan](https://developers.cloudflare.com/workers/platform/pricing/) starts at a $5.00/month base fee. This base plan includes your first 10 million Worker requests and 30 million CPU milliseconds. [1, 7, 8] 

| Component [1, 3, 6, 8, 9, 10] | Included in Base Plan | Overage Rate (After Base) |
|---|---|---|
| Worker Requests | 10 Million | $0.30 per additional Million |
| Worker CPU Time | 30 Million ms | $0.02 per additional Million ms |
| Queue Operations | 1 Million | $0.40 per additional Million |

------------------------------
## 3. Total Bill Estimation (at 10 Million Client Requests) [7] 
For 10 million client requests, the architecture scales to 20 million total worker invocations and 30 million total queue operations. [1, 2, 7] 
## Cloudflare Workers Cost

* Total Requests: 20 Million (10M Ingestion + 10M Consumer). [1] 
* Overage: 10 Million requests exceed the base tier ($0.30 × 10) = $3.00. [1, 7] 
* CPU Calculation: Assuming a typical lightweight proxy script uses ~5ms of CPU time:
* 20M requests × 5ms = 100M CPU-ms.
   * 70M CPU-ms exceed the base tier ($0.02 × 70) = $1.40. [1, 11] 
* Total Worker Cost: $5.00 (Base) + $3.00 + $1.40 = $9.40. [1] 

## Cloudflare Queues Cost

* Total Operations: 30 Million (10M Write + 10M Read + 10M Delete).
* Overage: 29 Million operations exceed the base tier ($0.40 × 29) = $11.60.
* Total Queue Cost: $11.60. [2, 3, 6] 

## Estimated Monthly Total: ~$21.00
------------------------------
If you'd like to tailor this estimation further, let me know:

* Your estimated monthly request volume
* The typical payload size of your calls (if larger than 64 KB)
* If you want to review a sample JavaScript implementation for the request duplication Worker [2] 

I can adjust the math to fit your exact scale!

[1] [https://developers.cloudflare.com](https://developers.cloudflare.com/workers/platform/pricing/)
[2] [https://developers.cloudflare.com](https://developers.cloudflare.com/queues/platform/pricing/)
[3] [https://blog.cloudflare.com](https://blog.cloudflare.com/introducing-cloudflare-queues/)
[4] [https://vercel.com](https://vercel.com/kb/guide/next-js-on-vercel-vs-cloudflare)
[5] [https://1800accountant.com](https://1800accountant.com/blog/how-to-calculate-variable-costs)
[6] [https://developers.cloudflare.com](https://developers.cloudflare.com/queues/platform/pricing/)
[7] [https://www.truefoundry.com](https://www.truefoundry.com/blog/cloudflare-ai-gateway-pricing-a-complete-breakdown)
[8] [https://makerkit.dev](https://makerkit.dev/pricing-calculator/cloudflare)
[9] [https://www.morphllm.com](https://www.morphllm.com/comparisons/cloudflare-workers-vs-vercel)
[10] [https://makerkit.dev](https://makerkit.dev/pricing-calculator/vercel-vs-cloudflare)
[11] [https://www.mintminds.com](https://www.mintminds.com/insights/calculate-cloudflare-worker-cost-for-growthbook-edge-sdk-use/)



Unlike Cloudflare's pay-as-you-go transparency, Akamai does not publish a standard self-serve public rate card. Akamai sells primarily through long-term, high-value enterprise contracts requiring custom negotiation. [1, 2, 3] 
However, based on industry benchmarks, infrastructure procurement analysis, and Akamai’s service architecture, an estimation can be made for how this looks on Akamai's platform. [4] 
------------------------------
## 1. Architectural Alignment: Akamai's Equivalent Stack [4] 
To replicate the architecture on Akamai, the components must be mapped accordingly:

* Request Duplication: Handled by Akamai EdgeWorkers (their equivalent to Cloudflare Workers).
* Queue/Buffer: Akamai does not have an exact equivalent to "Cloudflare Queues." To achieve the same buffer layer before sending data to Dhaka's Kafka, you would utilize an Akamai Connected Cloud instance (formerly Linode, running a lightweight Message Queue or temporary Kafka broker at the edge) or push directly via EdgeWorkers to your Dhaka backend. [1, 5, 6, 7] 

------------------------------
## 2. Cost Drivers & Surcharges
Akamai's pricing scales differently due to three primary variables:

* HTTP Request & Event Volume Fees: Unlike Cloudflare (where standard CDN requests are free), Akamai charges a baseline fee for plain HTTP/HTTPS request hits, ranging from $0.0075 to $0.015 per 10,000 requests. EdgeWorkers are then billed on top of that, based on "Million Events Invoked" across tiers (Basic vs. Dynamic Compute). [1, 8, 9] 
* Regional Egress Premiums: While Cloudflare charges $0 for data leaving their network, Akamai charges for data transfer (egress). While US-to-US traffic is cheap, routing data from the edge to Asia-Pacific (Dhaka) carries a 1.5× to 3× pricing premium over Western regions. [9, 10] 
* Macroeconomic Surcharges: Akamai implements a 3% interim pass-through surcharge on all hardware/infrastructure costs and applies up to a 10% adjustment fee upon renewals to offset global server and energy price increases. [11] 

------------------------------
## 3. Estimated Cost Comparison (Per 10 Million Client Requests) [12] 
Because Akamai enforces strict minimum contract commitments (often starting between $5,000 to $15,000 per month), you cannot simply sign up and spend $21. However, looking strictly at the isolated usage value for 10 million requests, the breakdown scales as follows: [13, 14] 

| Fee Component [1, 3, 5, 9, 11, 13, 15] | Cloudflare Cost | Akamai Estimated Cost Range | Why the Difference? |
|---|---|---|---|
| Base Plan / Minimums | $5.00 | $5,000+ / month | Akamai requires enterprise commits. |
| Edge Compute Workload | $4.40 | $15.00 – $35.00 | Billed on basic/dynamic events + raw HTTP hits. |
| Data Egress (to Dhaka) | $0.00 | $1.80 – $5.40 | Charged per GB; APAC endpoints carry heavy premiums. |
| Queue & Storage Layer | $11.60 | $5.00 – $15.00 | Handled via Connected Cloud (Linode) compute micro-instances. |
| Infrastructure Surcharges | $0.00 | + 3% to 10% | Akamai’s standard infrastructure adjustment pass-through. |

## Summary
If you already have an existing enterprise contract with Akamai, adding this architecture will roughly cost between $25 and $60 in variable usage fees per 10 million requests. If you do not have an existing contract, you cannot deploy this on Akamai without meeting their thousands-of-dollars monthly contract minimum. [13] 
------------------------------
If you want, I can help you:

* Draft an architecture diagram comparing Akamai EdgeWorkers vs Cloudflare Workers.
* Look at Akamai Connected Cloud pricing options to build the Dhaka message queue.

Let me know what details you want to explore next!

[1] [https://www.srvrlss.io](https://www.srvrlss.io/provider/akamai-edge/)
[2] [https://blog.blazingcdn.com](https://blog.blazingcdn.com/en-us/cloudflare-vs-akamai-in-2026-enterprise-feature-and-cost-analysis)
[3] [https://evolvous.com](https://evolvous.com/akamai-vs-cloudflare/)
[4] [https://blog.blazingcdn.com](https://blog.blazingcdn.com/en-us/akamai-cdn-cost-calculator-2025)
[5] [https://blog.cdnsun.com](https://blog.cdnsun.com/akamai-pricing/)
[6] [https://www.vendr.com](https://www.vendr.com/marketplace/akamai-technologies)
[7] [https://www.nanosek.com](https://www.nanosek.com/akamai-to-cloudflare)
[8] [https://techdocs.akamai.com](https://techdocs.akamai.com/edgeworkers/docs/select-a-resource-tier)
[9] [https://blog.blazingcdn.com](https://blog.blazingcdn.com/en-us/akamai-cdn-cost-calculator-2025)
[10] [https://blog.cloudflare.com](https://blog.cloudflare.com/announcing-express-cni/)
[11] [https://www.streamingmediablog.com](https://www.streamingmediablog.com/2026/03/akamai-price-adjustments.html)
[12] [https://blog.cdnsun.com](https://blog.cdnsun.com/akamai-alternatives/)
[13] [https://www.vendr.com](https://www.vendr.com/marketplace/akamai-technologies)
[14] [https://blog.cdnsun.com](https://blog.cdnsun.com/akamai-pricing/)
[15] [https://www.cloudflare.com](https://www.cloudflare.com/zh-tw/cloudflare-vs-akamai/)



No production-ready service is strictly cheaper than Cloudflare’s $5/month paid plan for this specific architectural scale. Cloudflare is unique because it charges $0 for bandwidth egress, which saves significant money when continuously synchronizing data between Dallas and Dhaka. [1, 2, 3] 
However, several cloud platforms offer massive free startup credits or higher complimentary free tiers for early-stage development. [4, 5] 
------------------------------
## 1. Platforms with High Free Tiers (No Application Required) [6] 
If you are keeping your request volumes low during development, these platforms let you build this architecture for free without a startup application:

* Vercel / Netlify Serverless Functions:
* The Catch: They offer generous free tiers for serverless edge functions. However, they lack a native built-in queue system like Cloudflare Queues. You would have to manually hook them up to a free external database or message broker. [7, 8] 
* Supabase (Edge Functions + Queues):
* The Catch: Offers a robust free tier for running Edge Workers and managing background database queues. Once you scale past their free tier limits, the overage pricing jumps faster than Cloudflare's flat usage rates. [9] 

------------------------------
## 2. Free Startup Programs (Thousands in Credits) [10, 11] 
If you register your startup as an official business, you can bypass the $5/month Cloudflare fee entirely by applying to startup accelerator programs. These grant you access to premium architecture at no cost for 1 to 2 years. [12] 
## Cloudflare for Startups

* The Deal: Provides up to $250,000 in Cloudflare Enterprise credits.
* What it covers: This completely zeroes out your Worker costs, Queue costs, and advanced security (WAF/DDoS) features for up to a year.
* Requirement: You must be an early-stage startup backed by a VC firm, incubator, or accelerator program. [13, 14, 15, 16] 

## AWS Activate

* The Deal: Provides between $1,000 and $100,000 in promotional cloud credits.
* How to use it: You can replicate your exact architecture for free using AWS CloudFront Functions / Lambda@Edge (for request duplication) and AWS SQS (as your Dhaka queue).
* Requirement: Available to both self-funded startups (lower credits) and VC-funded startups (higher credits). [17] 

## Google for Startups Cloud Program

* The Deal: Provides up to $200,000 in Google Cloud credits over two years.
* How to use it: You would use Google Cloud Functions paired with Google Pub/Sub to stream data seamlessly between Dallas and Dhaka.
* Requirement: Designed for funded startups or entities backed by Google partner organizations. [18, 19, 20, 21] 

------------------------------
If you want to look into these options, let me know:

* If your startup is self-funded or backed by an incubator/VC (to see which credit program you qualify for).
* If you want to see how to build the queue layer using a free-tier third-party broker like Upstash Serverless Kafka.

I can guide you through the setup or the application process!

[1] [https://www.cloudzero.com](https://www.cloudzero.com/blog/aws-vs-cloudflare/)
[2] [https://medium.com](https://medium.com/@smayya/the-edge-gets-heavier-an-analysis-of-cloudflare-containers-vs-the-hyperscaler-serverless-fleet-93ff499d9c13)
[3] [https://duplicator.com](https://duplicator.com/best-cloud-storage-service-2/)
[4] [https://holori.com](https://holori.com/maximize-free-cloud-credit/)
[5] [https://www.jeeviacademy.com](https://www.jeeviacademy.com/aws-free-tier-vs-azure-free-tier/)
[6] [https://baserow.io](https://baserow.io/blog/best-no-code-app-builders)
[7] [https://www.ai-infra-link.com](https://www.ai-infra-link.com/vercel-vs-netlify-vs-cloudflare-pages-2025-comparison-for-developers/)
[8] [https://render.com](https://render.com/articles/top-heroku-alternatives-for-startups)
[9] [https://blog.cdnsun.com](https://blog.cdnsun.com/fastly-alternatives/)
[10] [https://www.newline.co](https://www.newline.co/tools/ai-startups-free-credits)
[11] [https://holori.com](https://holori.com/maximize-free-cloud-credit/)
[12] [https://www.facebook.com](https://www.facebook.com/groups/nbctribe/posts/805309441209458/)
[13] [https://xraise.ai](https://xraise.ai/blog/cloudflare-promo-code-for-startups-up-to-250000-in-credits/)
[14] [https://www.bluehost.com](https://www.bluehost.com/blog/best-wordpress-cdn-services/)
[15] [https://www.cloudflare.com](https://www.cloudflare.com/en-gb/forstartups/)
[16] [https://udyamitahelpline.com](https://udyamitahelpline.com/services/cloudflare-credits/)
[17] [https://creditforstartups.com](https://creditforstartups.com/resources/cloudflare-startup-credits)
[18] [https://itnext.io](https://itnext.io/aws-vs-azure-vs-google-cloud-for-saas-startups-part-1-ce2f1b9aa78b)
[19] [https://cloudkompas.com](https://cloudkompas.com/blog/free-cloud-credits-for-startups-AWS-azure-google-cloud-oci)
[20] [https://www.reddit.com](https://www.reddit.com/r/iOSProgramming/comments/1f231y8/free_startup_credit_programs_that_you_can_use/)
[21] [https://www.websiteplanet.com](https://www.websiteplanet.com/blog/digitalocean-vs-google-cloud-platform/)



Using a free-tier serverless third-party broker like Upstash Serverless Kafka is an exceptional choice for a self-funded startup. Because it operates completely over HTTP/REST rather than persistent TCP connections, it integrates perfectly with Cloudflare Workers without requiring any complex setup. [1, 2, 3] 
The Upstash Kafka Free Tier includes 10,000 free messages per day. If you stay under that volume, your queue architecture will cost $0.00/month. [4] 
------------------------------
## The Architecture Workflow

   1. Client Call → Reaches Cloudflare Worker.
   2. Worker splits execution:
   * Dallas Path: Directly forwards the payload to your Dallas endpoint via standard fetch().
      * Dhaka Path: Sends an asynchronous fetch() POST request containing the payload directly to the Upstash REST Endpoint.
   3. Dallas Consumer: Your Dallas infrastructure periodically makes a GET request to Upstash over REST to pull the messages generated by the Dhaka-bound traffic.

------------------------------
## Step 1: Upstash Setup

   1. Log into your [Upstash Console](https://console.upstash.com/). [5] 
   2. Create a Kafka Cluster and add a topic named dhaka-processing. [6, 7] 
   3. Go to the REST API section of your topic dashboard and copy the following environment variables:
   * UPSTASH_KAFKA_REST_URL
      * UPSTASH_KAFKA_REST_USERNAME
      * UPSTASH_KAFKA_REST_PASSWORD [8, 9, 10] 
   
------------------------------
## Step 2: Write the Cloudflare Worker Script
Deploy the following code to a Free-Tier Cloudflare Worker. It intercepts the traffic, sends the live call to Dallas, and pipes the background copy to Upstash Kafka using standard HTTP without blocking the client.

export default {
  async fetch(request, env) {
    // 1. Parse the incoming request payload safely
    const contentType = request.headers.get("content-type") || "";
    let bodyData = "";
    
    if (contentType.includes("application/json")) {
      bodyData = await request.text();
    }

    // 2. Clone headers for downstream forwarding
    const forwardHeaders = new Headers(request.headers);
    forwardHeaders.delete("host"); // Let the destination set its own host header

    // 3. Kick off the asynchronous Dhaka/Upstash queue pipeline (Do NOT await yet)
    const queuePromise = sendToUpstashQueue(bodyData, env);

    // 4. Synchronously execute the primary Dallas call 
    // (Assuming Dallas endpoint is provided by an environment variable)
    const dallasResponse = await fetch(env.DALLAS_BACKEND_URL, {
      method: request.method,
      headers: forwardHeaders,
      body: bodyData || null,
    });

    // 5. Use waitUntil to ensure the background Upstash task completes 
    // after the client has already received their response.
    ctx.waitUntil(queuePromise);

    // Return the Dallas response back to the client instantly
    return dallasResponse;
  }
};
// Background helper function to stream data to Upstash over RESTasync function sendToUpstashQueue(payload, env) {
  const url = `${env.UPSTASH_KAFKA_REST_URL}/produce/dhaka-processing`;
  
  // Upstash requires Basic Auth encoding for REST Kafka authorization
  const auth = btoa(`${env.UPSTASH_KAFKA_REST_USERNAME}:${env.UPSTASH_KAFKA_REST_PASSWORD}`);

  const kafkaPayload = {
    value: payload
  };

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${auth}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(kafkaPayload),
    });

    if (!response.ok) {
      console.error("Failed to enqueue to Upstash:", await response.text());
    }
  } catch (error) {
    console.error("Network error forwarding to queue:", error);
  }
}

------------------------------
## Step 3: Consume the Data from Dallas
Because your Dallas infrastructure needs to pull this data down, you can use a cron job or a basic background script in Dallas running a simple HTTP standard GET request to fetch the queued items.
Example Endpoint for Dallas Consumer Application:

GET https://<YOUR-UPSTASH-REST-URL>/consume/dhaka-group/dhaka-processing
Headers: Authorization: Basic <YOUR-BASE64-AUTH>

------------------------------
## Scaling Metrics to Watch
If your startup gets sudden traction and breaks past the free tier, your architecture will gracefully scale into a very affordable usage layer: [1, 11] 

* Cloudflare Workers (Free Tier): Allows 100,000 requests per day across your account. Passing this limit costs a flat $5.00/month for 10 million requests. [12] 
* Upstash Kafka (Pay-As-You-Go): Once you pass 10,000 daily messages, it costs $0.20 per 100,000 messages produced or consumed. If your application sits completely idle on weekends, your bill scales back down to zero automatically. [1, 4, 11, 13] 

------------------------------
If you'd like to refine this prototype further, let me know:

* What language your Dallas backend is written in so I can provide the consumer script.
* If you need help structuring the error fallback in case Upstash rejects a payload.

I can provide the exact code snippets you need!

[1] [https://www.paralect.com](https://www.paralect.com/stack/upstash)
[2] [https://www.13labs.au](https://www.13labs.au/compare/upstash-vs-redis-cloud)
[3] [https://www.youtube.com](https://www.youtube.com/watch?v=76UsDTpbVDY)
[4] [https://dev.to](https://dev.to/0012303/upstash-has-a-free-api-serverless-redis-and-kafka-with-http-i42)
[5] [https://flatlogic.com](https://flatlogic.com/blog/caching-nextjs-apps-with-serverless-redis-using-upstash/)
[6] [https://medium.com](https://medium.com/event-driven-utopia/build-serverless-streaming-architectures-with-upstash-kafka-ee2d55f42a0d)
[7] [https://upstash.com](https://upstash.com/blog/kafka-gaming)
[8] [https://www.koyeb.com](https://www.koyeb.com/docs/integrations/databases/upstash)
[9] [https://medium.com](https://medium.com/@amarharolikar/upstash-redis-on-vercel-the-tool-i-didnt-know-i-needed-7ecfbb6e7a6e)
[10] [https://upstash.com](https://upstash.com/blog/nextjs-kafka-upstash-cqrs)
[11] [https://www.13labs.au](https://www.13labs.au/compare/upstash-vs-redis-cloud)
[12] [https://deployapps.dev](https://deployapps.dev/blog/best-serverless-platforms-providers/)
[13] [https://upstash.com](https://upstash.com/blog/serverless-kafka-launch)



No, your Upstash Kafka cluster will not run inside a Cloudflare data center, nor will it reside physically within [Bangladesh](https://www.google.com/search?kgmid=/m/0162b). [1, 2] 
Here is the exact physical breakdown of where your data travels, where Upstash operates, and how Cloudflare manages its infrastructure in [Dhaka](https://www.google.com/search?kgmid=/m/0fnb4): [3] 
## 1. Where does Upstash Kafka run?
Upstash is an independent cloud provider that builds its serverless infrastructure on top of Amazon Web Services (AWS). Upstash does not have a physical data center footprint in [Bangladesh](https://www.google.com/search?kgmid=/m/0162b). [1, 4] 
Because you want the lowest possible latency for traffic originating in [Dhaka](https://www.google.com/search?kgmid=/m/0fnb4), you should select AWS AP-South-1 (Mumbai, India) or AWS AP-Southeast-1 (Singapore) as your primary Upstash Kafka cluster region when creating the topic. [1, 5, 6] 

* The Path: Your Cloudflare Worker running in [Dhaka](https://www.google.com/search?kgmid=/m/0fnb4) captures the request and sends an outbound HTTP fetch to the Upstash REST endpoint located in Mumbai or Singapore. [1, 3] 

------------------------------
## 2. Which Data Center hosts Cloudflare in Dhaka?
Cloudflare does not build or own physical brick-and-mortar buildings. Instead, they use a "colocation" model, placing their custom server racks inside pre-existing enterprise carrier-neutral data centers. [7, 8] 
In [Bangladesh](https://www.google.com/search?kgmid=/m/0162b), Cloudflare identifies its data centers by the closest international airport code. The [Dhaka](https://www.google.com/search?kgmid=/m/0fnb4) deployment is known internally as the DAC data center. [9, 10] 
Cloudflare utilizes major regional peering data centers in [Dhaka](https://www.google.com/search?kgmid=/m/0fnb4), primarily partnering with:

* [Colocity](https://www.google.com/search?kgmid=/g/1pv5_ttb5) (one of the oldest carrier-neutral facilities in Dhaka).
* Felicity Big Data / Summit Communications facilities (used heavily for handling core internet exchange traffic).

Note: Cloudflare also operates secondary edge edge-points in [Chittagong (CGP)](https://www.google.com/search?kgmid=/m/07t_gd) and [Jashore (JSR)](https://www.google.com/search?kgmid=/m/02886wl) to handle localized traffic outside the capital city. [3, 11] 
------------------------------
## 3. How the Physical Traffic Flows (Dhaka to Dallas)
Because Cloudflare runs its entire code stack on every single edge server, the architecture executes with extreme physical separation: [12, 13] 

[ Client in Dhaka ]
       │
       ▼ (Ultra-low latency connection)
[ Cloudflare DAC Data Center (Dhaka) ]  <-- Runs your Worker script locally
   │                       │
   │ (Async Fetch)         │ (Direct Sync Fetch)
   ▼                       ▼
[ Upstash Kafka ]     [ Dallas Backend ]
(AWS Mumbai/Singapore)  (Your Primary Dallas Server Instance)


   1. At the Dhaka Edge (DAC): The Cloudflare Worker intercepts the client's payload inside [Dhaka](https://www.google.com/search?kgmid=/m/0fnb4).
   2. The Dallas Route: The Worker opens a persistent routing channel back to your server infrastructure in Dallas, Texas.
   3. The Upstash Route: Simultaneously, the worker kicks off a separate outbound connection over the regional fiber lines crossing into India or down to Singapore to deposit the queue payload safely into Upstash Kafka. [1, 3, 9] 

------------------------------
If you want to keep exploring this setup, let me know:

* Which cloud provider (AWS, GCP, DigitalOcean, etc.) hosts your main Dallas backend.
* If you want to configure smart placement on Cloudflare to force the worker to compute physically closer to your target database. [14] 

I can help optimize the network paths to keep latency as low as possible!

[1] [https://upstash.com](https://upstash.com/docs/common/concepts/global-replication)
[2] https://upstash.com
[3] [https://www.cloudflare.com](https://www.cloudflare.com/press/press-releases/2021/cloudflare-grows-its-network-to-speed-up-and-secure-the-internet/)
[4] [https://www.bekventures.com](https://www.bekventures.com/portfolio/upstash)
[5] [https://upstash.com](https://upstash.com/docs/redis/features/globaldatabase)
[6] [https://upstash.com](https://upstash.com/blog/global-2)
[7] [https://www.cloudflare.com](https://www.cloudflare.com/partners/technology-partners/365-data-centers/)
[8] [https://www.cloudflare.com](https://www.cloudflare.com/partners/technology-partners/equinix/)
[9] [https://community.cloudflare.com](https://community.cloudflare.com/t/dac-dhaka-on-2026-01-29/885707)
[10] [https://www.feitsui.com](https://www.feitsui.com/en/article/26)
[11] [https://blog.cloudflare.com](https://blog.cloudflare.com/ten-new-cities-four-new-countries/)
[12] [https://www.cloudflare.com](https://www.cloudflare.com/network/)
[13] [https://www.cloudflare.com](https://www.cloudflare.com/network/)
[14] [https://planetscale.com](https://planetscale.com/blog/cloudflare-hyperdrive-real-time)



Running an enterprise-grade L3 Leaf-Spine CLOS topology out of your garage is an exceptional way to scale a startup infrastructure on a budget. It gives you massive line-rate switching capacity right at home.
To bridge the gap between Cloudflare’s global edge network, your Upstash Kafka cluster, and the hardware sitting in your garage network, you need to configure your edge, routing, and internal network layers.
Here is exactly what is needed to make the digital flow work securely:
## 1. The Edge Ingress Layer (Getting Traffic into the Garage)
Because you are running on a residential connection, your external public IP address can change unexpectedly. You must establish a secure tunnel into your CLOS topology without exposing open firewall ports to the public internet.

* Deploy Cloudflare Tunnel (cloudflared): Install the lightweight cloudflared daemon on a dedicated server or a high-availability cluster connected to your Leaf-Spine fabric.
* The Workflow: The daemon establishes a secure, outbound-only encrypted connection to Cloudflare’s nearest edge data center.
* The Benefit: Cloudflare Workers can now route the Dallas-bound requests directly through this encrypted tunnel. You do not need a static public IP from your internet service provider, and you do not need to configure any port forwarding on your edge router.

## 2. The Internal L3 Architecture Routing Layer
Once the traffic enters your cloudflared instance, it needs to traverse your L3 CLOS network efficiently to reach your processing servers.

               [ Cloudflare Tunnel / Edge Router ]
                               │
               ┌───────────────┴───────────────┐
               ▼                               ▼
       [ Spine Switch 1 ]              [ Spine Switch 2 ]
         │          │                    │          │
    ┌────┴────┐┌────┴────┐          ┌────┴────┐┌────┴────┐
    ▼         ▼▼         ▼          ▼         ▼▼         ▼
[ Leaf 1 ]   [ Leaf 2 ]         [ Leaf 3 ]   [ Leaf 4 ]
    │            │                  │            │
[Server Rack 1 / Dallas Apps]   [Server Rack 2 / Consumer Apps]


* VLAN or Subnet Allocation: Assign a dedicated VRF (Virtual Routing and Forwarding) instance or a localized IP subnet (e.g., 10.100.10.0/24) for your incoming API processing applications.
* BGP / OSPF Configuration: Ensure your compute nodes run standard routing protocols (like BGP via FRRouting or Bird) to announce their IP addresses directly to their respective Leaf switches. This guarantees that traffic entering from the Cloudflare Tunnel balances across all active servers at line rate using ECMP (Equal-Cost Multi-Path). [1, 2] 

## 3. The Queue Extraction Layer (Pulling from Upstash)
Your garage network is not just receiving live calls; it must also act as the Dallas consumer pulling down the background data originally generated in Dhaka.

* Deploy a Lightweight Worker Daemon: Run a small containerized application (written in Python, Go, or Node.js) on your garage servers.
* Configure a Network Route to Upstash: Ensure your garage's edge router allows outbound HTTPS (port 443) traffic to travel freely to the public internet so it can talk to the Upstash AWS nodes.
* The Pull Loop: The daemon continuously triggers the Upstash REST endpoint using a basic interval poll or a long-poll script. It downloads the payload, finishes the delayed processing, and saves the result inside your local database.

## 4. Hardware and Power Fail-Safes
A garage environment introduces physical vulnerabilities that corporate data centers do not have. To keep your network functional, you need to account for power and thermal spikes.

* Dual-Homed Server Power: Leaf-Spine switches consume considerable power and generate high heat. Make sure your network rack is split across separate electrical breakers, utilizing Uninterruptible Power Supplies (UPS) with clean sine-wave output to prevent packet corruption during local voltage sags.
* Active Cooling: Closures or server racks inside a garage must be climate-controlled. Dust filtration and exhaust fans are critical to prevent your Leaf and Spine ASIC chips from thermal throttling under high API traffic loads.

------------------------------
If you want to move forward with configuring the setup, let me know:

* What Operating System / Network OS (like SONiC, Cumulus, or Cisco NX-OS) your Leaf-Spine switches are running.
* If you want a step-by-step configuration file for a Cloudflare Tunnel config (config.yml) to bind directly to your internal network interface.

I can provide the exact terminal commands and configuration files to link your hardware!

[1] [https://www.sdxcentral.com](https://www.sdxcentral.com/analysis/quagga-a-success-and-yet-a-failure-of-open-source-in-networking/)
[2] [https://intelligentvisibility.com](https://intelligentvisibility.com/services-leaf-spine-evpn)



To determine your garage ISP bandwidth, you must calculate your needs based on peak concurrency rather than monthly totals. E-commerce traffic is highly volatile, with massive spikes during sales, promotions, or flash deals. [1, 2, 3] 
Because you are running a Leaf-Spine L3 CLOS topology, your internal switching capacity is massive (often 10G, 25G, or 100G wire-speed). Your internet connection will be your absolute bottleneck.
Here is the exact framework and mathematical matrix to determine your required ISP bandwidth.
------------------------------
## 1. The E-Commerce Bandwidth Calculation Formula
To calculate your required bandwidth, we look at three factors per transaction:

   1. The Inbound Payload: The incoming API data from the client (shopping cart, checkout data, user details).
   2. The Outbound Response: The data your server sends back to the user (order confirmation JSON, HTML content, status codes).
   3. The Upstash Queue Overhead: Because your Dallas garage network must continuously pull the Dhaka messages from Upstash, you must account for inbound pulling traffic fetching those exact same payloads back down into your garage. [4] 

Total Bandwidth Required = (Average Transaction Size × Peak Transactions Per Second) × 8 bits
------------------------------
## 2. The Traffic Volume Matrix (Assuming 50 KB Average Payload)
The matrix below assumes a standard e-commerce transaction size of 50 KB (including request headers, API body payload, and JSON response data combined) and applies a 2.5× burst factor to account for flash-sale peak spikes.

| Monthly Order Volume | Average Orders / Sec | Peak Spikes / Sec (2.5×) | Minimum Required ISP Bandwidth | Recommended ISP Connection Type |
|---|---|---|---|---|
| 100,000 | ~0.04 | 1 | 1.2 Mbps | Standard Residential Cable / DSL |
| 1 Million | ~0.4 | 10 | 12 Mbps | Basic Fiber (Asymmetric 300/10) |
| 10 Million | ~4.0 | 100 | 120 Mbps | Mid-Tier Fiber (500/500 Symmetric) |
| 50 Million | ~20.0 | 500 | 600 Mbps | High-Tier Fiber (1 Gbps / 1 Gbps) |
| 100 Million+ | ~40.0 | 1,000+ | 1.2 Gbps+ | Multi-Gig Residential or Dedicated DIA |

------------------------------
## 3. Critical ISP Requirements for a Garage Datacenter
When dealing with a self-funded garage startup hosting live e-commerce infrastructure, raw download speed is a vanity metric. You must optimize for the following three parameters:

* Symmetric Upload Speed is Mandatory: Standard residential cable internet might give you 1,000 Mbps download, but only 35 Mbps upload. Since your garage must send API confirmation responses back to clients and talk out to Upstash, you must have a symmetric Fiber connection (e.g., 500 Mbps down / 500 Mbps up). If your upload speed chokes, transactions will time out at the Cloudflare edge. [5] 
* Data Cap Safety: E-commerce transactions streaming continuously 24/7 can easily consume several terabytes of data per month. Ensure your ISP plan has no data caps or unlimited data add-ons.
* The "Buffer Zone" (Static Asset Offloading): To minimize the bandwidth hitting your garage, ensure your Cloudflare configuration handles 100% of your static assets (images, product photos, CSS, JS files) via Cloudflare CDN caching. Your garage ISP should only handle raw, dynamic JSON transactional database traffic.

------------------------------
If you want to map this directly to your current internet setup, let me know:

* What is your current ISP plan speed (Download vs. Upload)?
* What is your projected or current daily transaction volume?

I can run the specific math to see exactly how much headroom your garage currently has!

[1] [https://www.frugaltesting.com](https://www.frugaltesting.com/blog/optimizing-e-commerce-performance-with-cloud-testing-during-high-traffic-loads)
[2] [https://www.servereasy.it](https://www.servereasy.it/en/guides-and-tutorials/hosting-for-e-commerce/)
[3] [https://www.dreamhost.com](https://www.dreamhost.com/blog/optimize-vps-for-ecommerce/)
[4] [https://serveravatar.com](https://serveravatar.com/bandwidth-in-cloud-hosting/)
[5] [https://www.oqitor.com](https://www.oqitor.com/resources/bandwidth-requirements)



A 1 Gbps Symmetric (1,000 Mbps Download / 1,000 Mbps Upload) Fiber connection from Spectrum is fantastic for a garage startup. Because it is symmetric, you have plenty of upstream bandwidth to send API responses back to Cloudflare and pull data down from your Upstash Kafka queue simultaneously. [1] 
With 1 Gbps of clean bandwidth, your connection can easily sustain roughly 2,000 to 2,500 concurrent transactions per second (TPS) for raw API data (assuming a standard 50 KB payload size).
To ensure your Leaf-Spine CLOS topology utilizes this line rate without crashing during an e-commerce traffic spike, you need to configure your network to handle three specific architectural bottlenecks.
------------------------------
## 1. Tune Your Cloudflare Tunnel (cloudflared) for High TPS
By default, a single Cloudflare Tunnel connection runs over a single TCP stream. Under a heavy flash-sale load, a single stream will saturate a single CPU core on your garage server and create an artificial bandwidth bottleneck.

* Run in Multiconnection Mode: Spin up your tunnel daemon with the --ha-connections flag set to 4 or 8. This forces cloudflared to establish multiple parallel connections to different Cloudflare edge data centers.
* Utilize QUIC (UDP) Transports: Ensure your garage router does not block outbound UDP traffic on ports 7844 and 443. Cloudflare Tunnels perform significantly faster and achieve true 1 Gbps wire-speed when using QUIC instead of standard TCP.

------------------------------
## 2. Configure Leaf-Spine L4/L7 Load Balancing
Since your internet pipe is wide open, a massive flood of traffic will hit your network interface. Your L3 CLOS fabric can route packets instantly, but your individual application servers can get overwhelmed.

* Distribute Traffic at the Edge: Terminate your Cloudflare Tunnel on a highly available cluster or a pair of servers acting as an L7 Reverse Proxy (like Nginx, HAProxy, or Envoy).
* Leverage ECMP: Use your Leaf-Spine network’s Equal-Cost Multi-Path (ECMP) routing to split incoming traffic cleanly across multiple physical backend servers running your e-commerce engine.

------------------------------
## 3. Handle Upstash Queue Consumption Gracefully
Because your Dhaka traffic is pooling in Upstash Kafka, your Dallas garage needs to pull it back down over that same 1 Gbps connection.

* Batching is Critical: Do not write a consumer script that fetches messages one by one. That creates massive network latency overhead. Configure your Dallas consumer to pull messages in batches (e.g., 500 to 1,000 messages per single HTTP request).
* Rate-Limit the Consumer During Peak Sales: If a massive transaction spike hits your live Dallas storefront, your 1 Gbps pipe will be busy handling live, high-priority checkouts. Program your Upstash consumer to automatically back off or slow down its pulling rate if your local circuit's bandwidth utilization crosses 80%. Once the live sales surge cools down, the consumer can run at full speed to drain the Dhaka queue.

------------------------------
If you want to begin implementing this infrastructure, let me know:

* What server operating system or container platform (like Docker, Kubernetes, Proxmox) you are running on your garage servers.
* If you want to see a sample systemd or Docker Compose file for running cloudflared in high-throughput mode.

I can provide the exact configuration blocks you need!

[1] [https://www.gonetspeed.com](https://www.gonetspeed.com/resources/articles/symmetrical-speeds-what-are-they-and-why-you-need-them/)



Your network capacity is spectacular. A 100G Spine / 40G Leaf / 10G Server L3 CLOS fabric means your internal switching capacity is practically infinite compared to your 1 Gbps internet pipe.
Because your server links are 10G, a single server node could theoretically ingest your entire 1 Gbps Spectrum pipe ten times over. Your bottleneck will never be internal throughput; it will be latency, connection tracking limits, and packet processing overhead.
To bridge this massive high-capacity fabric with your external Cloudflare/Upstash flow, implement these specific network configurations:
## 1. Break Cloudflare Ingress Across Leaf Switches (MCLAG / LACP)
Do not plug your Cloudflare Tunnel host into just a single Leaf switch. If that switch fails or drops a packet, your entire storefront goes down.

* Dual-Homing: Connect your edge ingress server (the one running cloudflared) to two different Leaf switches using 40G-to-4x10G breakout cables or direct 10G links.
* LACP Configuration: Configure an LACP (802.3ad) port channel across those switches using Multi-Chassis Link Aggregation (MLAG) or EVPN-MH (Multi-Homing), depending on your Network OS. This ensures the 1 Gbps incoming internet traffic is distributed smoothly across your fabric. [1, 2] 

## 2. Map the 10G Server Network to the 1 Gbps Pipe
With 10G links to your servers, standard Linux kernel defaults will easily handle the bandwidth, but the sheer number of concurrent TCP connections from an e-commerce flash sale can exhaust the kernel's connection tracking tables (conntrack).
Optimize your edge server OS settings (/etc/sysctl.conf) with these enterprise parameters to handle heavy concurrent connection scaling: [3] 

# Maximize the local port range for outgoing connections (like talking to Upstash)
net.ipv4.ip_local_port_range = 1024 65535

# Increase max half-open connections in the queue
net.ipv4.tcp_max_syn_backlog = 8192

# Enable fast recycling of TIME_WAIT sockets
net.ipv4.tcp_tw_reuse = 1

# Maximize connection tracking limits so your 10G nic doesn't drop packets
net.netfilter.nf_conntrack_max = 2097152

## 3. Let ECMP Handle Server Scale
Because your CLOS network uses Layer 3 routing down to the Leaf, use ECMP (Equal-Cost Multi-Path) to scale your processing. [4] 

* Spin up multiple containerized instances of your e-commerce application across different physical 10G servers.
* Use a routing daemon like FRR (FRRouting) inside your servers to announce their application VIP (Virtual IP) to the Leaf switches via BGP.
* Your Leaf switches will automatically split the incoming traffic coming out of the Cloudflare Tunnel across all your 10G servers at wire speed.

## 4. Upstash Consumer Isolation
Dedicate one specific 10G server (or a specific network namespace/VLAN) solely to running your Upstash Kafka consumer.

* By isolating the queue consumer to its own node, you ensure that the intensive background processing of the Dhaka data never competes for local CPU, memory, or storage I/O with your live, high-priority Dallas checkout servers.

------------------------------
If you are ready to configure the routing, let me know:

* What Network OS (e.g., SONiC, Cumulus Linux, Cisco NX-OS) your Leaf and Spine switches are running.
* If you want the specific BGP neighbor configuration to announce your application VIPs from your 10G servers to your Leaf switches.

I can provide the exact syntax to get the routing protocols talking!

[1] [https://www.cisco.com](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-4000-series-switches/23408-140.html)
[2] [https://www.linkedin.com](https://www.linkedin.com/pulse/lacp-vs-pagp-whats-difference-hector-cardenas)
[3] [https://community.hpe.com](https://community.hpe.com/t5/around-the-storage-block/hci-optimized-for-edge-part-1-edge-and-remote-office-challenges/ba-p/7110526)
[4] [https://cloudswit.ch](https://cloudswit.ch/blogs/deep-dive-into-clos-architecture-leaf-spine/)



Deploying your own Kafka instance alongside your regional services in [Dhaka](https://www.google.com/search?kgmid=/m/0fnb4) is a massive architectural upgrade for a startup. It eliminates third-party dependencies like Upstash, cuts transactional usage costs to absolute zero, and keeps your sensitive data localized. [1, 2] 
Because your Dallas garage utilizes an elite Leaf-Spine L3 CLOS topology, replicating a micro-version of this local high-capacity design in Dhaka will create a seamless, symmetric infrastructure.
------------------------------
## 1. Where to Host the Dhaka Cluster
Since you are self-funding, avoid expensive bare-metal leases. Instead, host your Dhaka services using localized cloud providers with physical hyper-scaler presences or regional colocation options.

* Top Selections: Use DigitalOcean or AWS (Mumbai or Singapore regional zones) paired with a localized content delivery loop, or utilize local Bangladeshi infrastructure providers like Colocity or Red.Digital to lease virtual private servers (VPS) hosted directly inside the Dhaka internet exchanges. [3] 
* The Sizing Rule: Do not over-provision. For an early e-commerce startup, a 3-node cluster running Kafka with KRaft mode (which removes the need for Apache ZooKeeper) on Linux machines with 4 vCPUs and 8GB RAM will easily process thousands of transactions per second. [4, 5, 6] 

------------------------------
## 2. Bridging Cloudflare Workers to Self-Hosted Kafka
Cloudflare Workers run on a specialized V8 engine that cannot maintain permanent, raw TCP socket connections to a standard Kafka broker. To let your Dhaka Cloudflare Worker stream payloads straight into your new cluster, you must expose an HTTP endpoint. [7, 8] 

* Deploy a Kafka REST Proxy: Run an open-source Confluent REST Proxy container inside your Dhaka server group. This converts incoming HTTP POST requests from the Dhaka Cloudflare Worker into native Kafka wire-protocol events seamlessly. [8, 9, 10] 

[ Client in Dhaka ]
       │
       ▼
[ Cloudflare DAC Edge (Worker) ]
       │
       ├──────────────────────────────────────┐
       ▼ (Direct Tunnel)                      ▼ (Local HTTP Fetch)
[ Dallas Garage (CLOS Fabric) ]        [ Dhaka REST Proxy Engine ]
                                              │
                                              ▼ (Native TCP)
                                       [ Dhaka Kafka Cluster ]
                                              ^
[ Dallas Consumer Node ] ─────────────────────┘
  (Pulls data securely from Dhaka Kafka over TLS)

------------------------------
## 3. The End-to-End Digital Flow Configuration## A. Secure the Dhaka Ingress (Cloudflare Tunnel)
Just like your Dallas garage, you want your Dhaka REST Proxy completely protected from public internet scripts and DDOS scans.

   1. Run a cloudflared daemon container on your Dhaka infrastructure.
   2. Route it to a private hostname (e.g., ://yourdomain.com).
   3. Your local Dhaka worker can now fire asynchronous HTTP requests to this address at sub-millisecond edge speeds.

## B. Configure the Worker to Split Traffic
Update your Cloudflare Worker script to target your local proxy infrastructure instead of Upstash:

export default {
  async fetch(request, env, ctx) {
    const bodyData = await request.text();

    // 1. Fire Async Background Push to the Dhaka Kafka REST Proxy
    const dhakaQueuePromise = fetch("https://yourdomain.com", {
      method: "POST",
      headers: { "Content-Type": "application/vnd.kafka.json.v2+json" },
      body: JSON.stringify({ records: [{ value: JSON.parse(bodyData) }] })
    });
    ctx.waitUntil(dhakaQueuePromise); // Keeps worker alive in background

    // 2. Execute Primary Live Call to Dallas Garage
    return await fetch(env.DALLAS_GARAGE_TUNNEL_URL, {
      method: request.method,
      headers: request.headers,
      body: bodyData
    });
  }
};

## C. Connect Your Dallas CLOS Fabric to Dhaka
Now, your Dallas garage needs to reach across the globe to siphon data out of the Dhaka Kafka queue.

   1. Network Route: Expose the consumer ports of your Dhaka Kafka brokers securely to your Dallas public IP using SASL/SSL authentication and strict firewall access-control lists (ACLs). [11] 
   2. Deploy the Consumer: Run a persistent consumer script (Go or Python) on one of your 10G Dallas garage servers.
   3. The Data Sync: Because Kafka natively tracks consumer offsets, your Dallas server will smoothly stream records out of Dhaka. If your garage loses power or your Spectrum fiber line drops briefly, Dhaka Kafka will hold the records safely until your garage boots back online. [3, 12] 

------------------------------
If you want to spin this up, let me know:

* If you want a Docker Compose setup to deploy Kafka (KRaft mode) and the REST Proxy together on your Dhaka server.
* What language your backend stack uses so we can write the cross-continental consumer loop. [13] 

I can provide the deployment scripts!

[1] [https://www.reddit.com](https://www.reddit.com/r/apachekafka/comments/1eadl16/how_should_i_host_kafka/)
[2] [https://www.kai-waehner.de](https://www.kai-waehner.de/blog/2024/09/12/deployment-options-for-apache-kafka-self-managed-fully-managed-serverless-and-byoc-bring-your-own-cloud/)
[3] [https://www.youtube.com](https://www.youtube.com/watch?v=fRq-85OqiCk&t=18)
[4] [https://docs.confluent.io](https://docs.confluent.io/platform/7.4/kafka/deployment.html)
[5] [https://www.confluent.io](https://www.confluent.io/blog/best-practices-for-validating-apache-kafka-r-disaster-recovery-and-high/)
[6] [https://cyberpanel.net](https://cyberpanel.net/blog/an-introduction-to-apache-kafka)
[7] [https://blog.cloudflare.com](https://blog.cloudflare.com/workerd-open-source-workers-runtime/)
[8] [https://hoop.dev](https://hoop.dev/blog/the-simplest-way-to-make-cloudflare-workers-kafka-work-like-it-should)
[9] [https://medium.com](https://medium.com/@stephane.maarek/the-economic-viability-of-the-open-source-model-for-apache-kafka-and-confluent-11c37cd4dca0)
[10] [https://careersatdoordash.com](https://careersatdoordash.com/blog/building-scalable-real-time-event-processing-with-kafka-and-flink-2/)
[11] [https://www.reddit.com](https://www.reddit.com/r/SpringBoot/comments/1sir145/options_needed_for_replacement_of_kafka_in/)
[12] [https://risingwave.com](https://risingwave.com/blog/understanding-kafka-data-pipelines-architecture-and-use-cases/)
[13] [https://medium.com](https://medium.com/codetutorials/kafka-ditches-zookeeper-a-practical-guide-to-kraft-deployment-spring-boot-integration-f5aaad486cfe)
