# trade-tariff-classification-examples

## Running the batch labelling job

This application uses ActiveJob with a SolidQueue backend to process commodities in batches.

### Running the worker

To process the jobs, you need to start the SolidQueue worker. You can do this by running the following command:

```bash
bin/jobs
```

### Triggering the job

To trigger the batch labelling job, you can run the following Rake task:

```bash
bundle exec rake labelling:batch_label
```

This will enqueue a job for each batch of commodities that need to be labelled.

### Configuring the batch size

You can configure the batch size by setting the `BATCH_LABEL_SIZE` environment variable. The default value is 10.
