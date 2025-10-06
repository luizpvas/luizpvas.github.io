-- title: Tracking visits with image tags
-- publication_date: 2023-10-06
-- summary:

Have you ever noticed analytics services such as Google Analytics, Fathom, Mixpanel and Hotjar use an `<img>` tag to track visits? Even when there's an integration script, the script dynamically builds an image element instead of directly sending AJAX requests.
There are three good reasons for this:

1. **Images skip preflight CORS requests.** Analytics trackers are designed to run on other people's websites. Browsers know when you're sending a request to a domain other than the one you're currently visiting, and when that happens a preflight OPTIONS request is sent to make sure the server accepts the request. One OPTIONS request plus the actual request you wanted to send. We can cut the amount of requests in half by using an image.
2. **Images can be used in emails.**
4. **Browser compability**. The `fetch` API is pretty widespread, but `<img>` tags just work everywhere.
