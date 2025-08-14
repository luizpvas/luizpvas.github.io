-- title: Controllers and views
-- publication_date: 2023-08-31
-- summary: Code that changes together should be close together

In server-side rendered MVC web applications, views are functions `args -> string` and controllers are functions `untrusted_args -> string`. Controllers authorize the request, validate inputs, run some queries, etc. and then respond with a `render` call.

Controllers are responsible for gathering and formatting data needed **for a specific view**, with the specific names and fields the view requires. Even though the controller does not care about how things look visually and how they're arranged, it has to know about the shape of the data.

But the dependency goes both ways. Views know about controllers just as much as controllers know about views.
You can't just change the endpoint of a form or remove a field and expect the app to continue working.
Forms submit data to one specific endpoint.
Controllers render one specific view.

Think about how often you have to change both of them, in the same pull request, to ship a working feature to production.

### Code that changes together should be close together

Code that changes together should be in the same file. Files that change together should be in the same directory. You should be able to look at the directory structure of your app and understand what is is about, what it does, what things are related to what things.

If that sounds similar to the S principle in SOLID, it does because it is.

Here's an example of the opposite idea of "code that changes together should be close together":

```bash
my_app/
  controllers/
    billing/
      payment_controller.rb
  validators/
    billing/
       payment_validator.rb
  serializers/
    billing/
      payment_serializer.rb
  models/
    billing/
      payment.rb
  views/
    billing/
      payments/
        new.html.erb
```

All those abstractions look like they're about the same feature, don't they?

### Tweaking Rails

Rails provides the method [`prepend_view_path`](https://api.rubyonrails.org/v7.0/classes/ActionView/ViewPaths/ClassMethods.html#method-i-prepend_view_path) that adds a lookup path for templates. You can use it to place your templates right next to the controller that renders them.

```ruby
class ApplicationController < ActionController::Base
  prepend_view_path Rails.root.join("app/controllers")
end
```
