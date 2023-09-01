-- title: Controllers and views
-- publication_date: 2023-08-31
-- summary: Code that changes together should be close together

In server-side rendered web applications, views are functions `args -> string`. Controllers are functions `untrusted_args -> string`. Controllers authorize the request, validate inputs, run some queries, etc. and then respond with a `render` call.

Controllers are responsible for gathering and providing the data needed **for a specific view**, with the specific names and fields the view requires. Even though the controller does not care about how things look visually and how they're arranged, it has to know about the shape of the data.

But the dependency goes both ways. Views know about controllers just as much as controllers know about views.
You can't just change the endpoint of a form and expected the app to continue working.
You can't just remove a field from a form and expected the app to continue working.

Forms are designed to submit data to one specific endpoint.
Controllers are designed to render one specified view.

Think about how often you have to change both of them in the same pull request.

* You add a new field that you read, validate and store.
* You change a value to a list of values and validation has to change.
* You add some hidden inputs to pass around a parameter needed by some endpoint down the line.

### Code that changes together should be close together

Controllers and views are indeed different abstractions, but they're tightly coupled.

Here is a rule of thumb for all software: code that changes together should be close together. If that sounds similar to the S principle in SOLID, it does because it is. Code that changes together should be in the same file. Files that change together should be in the same directory. You should be able to look at the directory structure of your app and understand what is is about, what it does, what things are related to what things.

Here's an example of a pull request overview with the opposite idea of "code that changes together should be close together":

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

All those abstractions look like they're about the same concept, don't they? Why do we insist in putting them so far apart from each other?

### Controllers and views next to each other

Here's a Rails trick you can use to place controllers and views next to each other: [`prepend_view_path`](https://api.rubyonrails.org/v7.0/classes/ActionView/ViewPaths/ClassMethods.html#method-i-prepend_view_path).

```ruby
class ApplicationController < ActionController::Base
  prepend_view_path Rails.root.join("app/controllers")
end
```

You can now place your views in the same directory.

```
  app/
    controllers/
      payments/
        invoices/
          index.html.erb
          new.html.erb
          create.turbo-stream.erb
        invoices_controller.rb
```
