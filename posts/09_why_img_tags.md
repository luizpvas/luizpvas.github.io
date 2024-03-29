-- title: Tracking visits with image tags
-- publication_date: 2023-10-06
-- summary:

Have you ever noticed Google Analytics, Fathom, Mixpanel, Hotjar and all others use an `<img>` tag to track visits? Even when there's
an integration script, the script dynamically builds an image element on the page instead of sending an AJAX request.

There are 4 main reasons for that.

1. **Images skip preflight CORS requests.** Analytics trackers are designed to run on other people's websites. Browsers know when you're sending a request to a domain other than the one you're currently visiting, and when that happens a preflight OPTIONS request is sent to make sure the server accepts the request. One OPTIONS request plus the actual request you wanted to send. We can cut the amount of requests in half by using an image.
2. **Images can be used in emails.**
3. **Harder to detect.** I dislike this reason, and I'm not sure it still holds true today. Trackers should be detectable.
4. **Browser compability**. The `fetch` API is pretty widespread, but I would consider an `<img>` tag to just work everywhere. 
