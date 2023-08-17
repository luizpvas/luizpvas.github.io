-- title: The controller abstraction
-- publication_date: 2023-08-06
-- summary: Core communicates with extensions via event broadcasting, and each event has an implicit contract. Let's make them explicit.

Disclaimer: this post was written from the perspective of building web apps mainly with server rendered HTML with frameworks such as Rails, Laravel or Django.

Controllers are not the best abstraction for building the UI of a web application. We have already discovered better tools to build
that page that lists something and shows the details about each thing when you click on it, or that complex multistep form that aggregates
what you type and then do something at the end.

#### Controllers and views are the same thing

Views are functions `args -> string`. Controllers are functions `untrusted_params -> string`. Controllers validate, authorize, run some queries, etc. and then call the view and send the output to the client.

Controllers are responsible to format and gather the data needed *for a specific view*, with the specific names and fields the view requires.
This is the important bit. The view has a contract and the controller knows about it. The controller *has* to know about it, otherwise we would
get runtime errors while rendering the view.

But the dependency goes both ways. The view knows about the controller just as much as the controller knows about the view.
You can't just change the endpoint of a form to and expected the app to continue working.
You can't just delete a field from a form and expected the app to continue working.

Forms submit data in a specific format that one specific controller can handle.

Do you see where am I going?

Here's another way to think about coupling between controllers and views. Think about how often you have two change both of them, in the same pull request, to accomodate for a new feature.
You add a new field or a new parameter that you then read and validate on the controller.
You change a field to be a list of fields and now you need to parse the list of values that arrive.
You change the 

Now, of course there are exceptions. Visual changes only touches the view. Authorization changes only touches the controller. But the vast majority
of changes, the ones that change the behaviour of the app, touches both *at the same time*.

So, what can we do about it?

#### Better, higher level abstractions

Livewire and LiveView have proven there is a better way to build UIs. The rendered HTML 

#### Code that change together should be close together

Here is a rule of thumb for all software development: code that change together should be close together. Close together in the physical
sense. Files that change together should be near each other. In the same directory if possible. You should be able to look at the directory structure of your app and understand what is is about, what it does, what things are related to what things.

To constrat with this idea of proximity (what not to do), have you ever worked in a feature that resulted in a PR that looked like this?

```bash
my_app/
  controllers/
    payments/
      invoice_controller.rb # (+10 lines)
  validators/
    payments/
       invoice_validator.rb # (+18 lines, -1 line)
  serializers/
    payments/
      invoice_serializer.rb # (+3 lines, -2 lines)
  models/
    payments/
      invoice.rb # (+1 line)
  views/
    payments/
      invoices/
        new.html.erb # (+29 lines)
```

I certainly did. Organizing your app by patterns and abstractions works, but I believe there are better ways.

To 

`prepend_view_path`
