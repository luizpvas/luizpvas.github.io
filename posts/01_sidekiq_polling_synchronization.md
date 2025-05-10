-- title: Random sleep poller
-- publication_date: 2023-03-04
-- summary: Sidekiq's scheduling system is designed to avoid the need of distributed coordination. Let's explore that.

Sidekiq jobs can run either as soon as possible or be scheduled to run at a later time.

Run as soon as possible uses a **list**. Jobs are added with `LPUSH` and picked up by the processor using `BRPOP`.

Run at a later time uses a **sorted set**. Jobs are added with `ZADD` and picked up by the poller with `ZRANGEBYSCORE`.

### Polling for scheduled jobs

We can start many Sidekiq processes. Each process has a single poller and many processors controlled by the `concurrency` config. The poller is responsible to fetch jobs that are due for execution and enqueuing them, and processors are responsible to executing jobs.

Sidekiq provides the config `average_scheduled_poll_interval` to control how often pollers check for scheduled jobs across the entire cluster. There's a problem, though. Imagine we have 30 Sidekiq processes running in different servers and we set `average_scheduled_poll_interval` to 15 seconds. How can those 30 processes coordinate to meet the configured average?

This is a distribution problem. Pollers need to be aware of each other so they can agree on the polling interval. Distributed coordination is an extremely difficult problem to solve correctly, and generally should be avoided.

Sidekiq solves this problem by [sleeping a random amount of time based on the amount of processes in the cluster](https://github.com/sidekiq/sidekiq/blob/main/lib/sidekiq/scheduled.rb#L129-L160). This is possible because Sidekiq knows how many processes are running by looking at the heartbeat data, also stored in Redis.

Back to our problem. If we have 30 processes and want to poll for scheduled jobs every 15 seconds, we can ask each poller to sleep for `(30 * 15 * rand) seconds` before polling. Sleep a random of time, then wake up and schedule. Rinse and repeat. Just by doing this we'll get very close to meeting the 15 seconds interval cluster-wide average.

All processes run the same code with the same configuration. There are no leaders with different responsibilities and there is no coordination involved.
