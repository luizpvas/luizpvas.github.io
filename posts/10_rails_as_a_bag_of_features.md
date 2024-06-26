-- title: Rails as a bag of features
-- publication_date: 2023-10-29
-- summary:

Sending and receiving emails, storing attachments, generating thumbnails, CSRF protection, XSS protection, mime type negotiation, session and cookie management, password hashing, rendering templates, broadcasting websocket events, broadcasting DOM patches, scheduling background jobs, managing database migrations, caching, integrated testing, app-wide configuration and secrets, asset management, database encrypted attributes, probably the best active record pattern implementation - and a lot more.

Those are all great. Use them.

## Rails as an app generator

Rails follows the MVC pattern. Looking at Rails from the lens of the layered architecture, controllers and views are part of the presentation layer and models are part of the application, domain and infrastructure layer.

Some people like to extend Rails with new abstractions like `app/forms`, `app/filters`, `app/queries`, `app/notifications`, `app/components` and so on. Such abstractions are born out of the feeling that vanilla Rails does not provide enough places for our code.

I believe this is the wrong approach. Rails should not dictate where we put our code just as much as abstractions should not dictate where we put our code.

In the same spirit as [Phoenix is not your application](https://www.youtube.com/watch?v=lDKCSheBc-8): Rails is not your application. Your application is about customer support, or about email marketing, or about project management, or about selling concert tickets. Your app uses Rails to expose a web interface, and to manage assets, and to schedule background jobs, and to store files, etc.

Those are two different things.
