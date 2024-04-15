-- title: Measuring performance
-- publication_date:
-- summary:

Three questions to ask when thinking about web app performance, speed and scalability:

## 1. How fast does the app feel?

Pick a random user and observe them using the app. Do not look at server metrics, database, queues or anything
the user does not know the existence. Does it feel fast? Good. Does it feel slow? Fix it, because no optimization
makes sense in this scenario.

Consider asset bundle size, browser extensions, slow devices, slow network, distance between users and servers.

## 2. How fast is the system under a spike of requests?

In which ways is the system affected when there is a spike of requests?

## 3. How does the system behave over time?

In which ways is the system affected when the app keeps being used over the period of weeks, months, years?
This is usually
