-- title: IO bound parsing
-- publication_date: 2023-09-02
-- summary: Threads to the rescue - or not

In Ruby MRI, only one VM instruction can run at a time. No parallelism at all. However, we can have concurrent execution when threads are waiting for IO.
The Ruby VM executes instructions sequentially for a given thread until it reaches an IO call.
While waiting for IO to finish in background, the Ruby VM jumps to another thread and starts executing its instructions until it
reaches some other IO call. Rinse and repeat.

I've been working on a [language server for Ruby](https://github.com/luizpvas/holistic-ruby/) for the past couple of months. During initialization,
the language server reads the app's source code, parses it and indexes the parsed data in a single thread.

#### Can I speed up `holistic-ruby` with threads?

Another way to phrase this question is: "is the code I'm trying to optimize IO bound?". Let's see.

The following is a benchmark for initializing `holistic-ruby` on different popular libraries. It measures the time spent on 1) reading the app's source code, 2) converting the source code into AST and indexing the data, and 3) running the type inference algorithm.

app | amount of files | file reading | parsing and indexing | type inference
:---:|:---:|:---:|:---:|:---:
newrelic-ruby-agent | 1009 | 0.008818727982s | 2.44959996399s | 0.185098429999s
sidekiq | 120 | 0.00107567099985s | 0.27185193400s | 0.0096343349996s
devise | 201 | 0.00229818698971s | 0.29916613001s | 0.011243356999s

![benchmark chart result in percentage](/images/06_io_bound_benchmark.png)

Even if I managed to make the IO part instantaneous, the overall performance of the system would improve by +- 0,5%. Definetly not IO bound and not worth the trouble of adding threads.

Ractors on the other hand...
