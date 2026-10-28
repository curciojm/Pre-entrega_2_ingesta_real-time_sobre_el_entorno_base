import boto3
import json
import time
import datetime
import random
import uuid


class KinesisProducerConsumer:
    def __init__(self, stream_name):
        self.kinesis = boto3.client('kinesis')
        self.stream_name = stream_name

    
    def producer_efficient_batch(self, events):
        batch_size = 100
        max_retries = 5

        for start in range(0, len(events), batch_size):
            batch = events[start:start + batch_size]

            records = [
                {
                    "Data": json.dumps(event).encode("utf-8"),
                    "PartitionKey": str(uuid.uuid4())
                }
                for event in batch
            ]

            response = self.kinesis.put_records(
                StreamName=self.stream_name,
                Records=records
            )

            failed_count = response["FailedRecordCount"]

            if failed_count:
                print(f"Fallaron {failed_count} registros")

                failed_records = [
                    records[i]
                    for i, result in enumerate(response["Records"])
                    if "ErrorCode" in result
                ]

                attempt = 0
                while failed_records and attempt < max_retries:
                    attempt += 1
                    print(
                        f"Reintento {attempt}: "
                        f"{len(failed_records)} registros fallidos"
                    )
                    time.sleep(min(2 ** (attempt - 1), 16))
                    retry_response = self.kinesis.put_records(
                        StreamName=self.stream_name,
                        Records=failed_records
                    )
                    failed_records = [
                        record
                        for record, result in zip(
                            failed_records, retry_response["Records"]
                        )
                        if "ErrorCode" in result
                    ]
                if failed_records:
                    print(
                        f"Advertencia: quedaron {len(failed_records)} "
                        "registros sin enviar."
                    )

    def simple_consumer(self, shard_id):
        response = self.kinesis.get_shard_iterator(
            StreamName=self.stream_name,
            ShardId=shard_id,
            ShardIteratorType="TRIM_HORIZON"
        )

        iterator = response["ShardIterator"]

        while iterator:
            response = self.kinesis.get_records(
                ShardIterator=iterator,
                Limit=100
            )

            for record in response["Records"]:
                data = json.loads(record["Data"])
                print(data)

            iterator = response.get("NextShardIterator")

            if not response["Records"]:
                time.sleep(1)

# Configura tu stream y prueba la lógica
if __name__ == "__main__":
    STREAM_NAME = "dev-kinesis-ingest-stream"
    app = KinesisProducerConsumer(STREAM_NAME)

    events = [
        {
            "EVENT_TIME": datetime.datetime.now().isoformat(),
            "TICKER": random.choice(["AAPL", "AMZN", "MSFT", "INTC", "TBV"]),
            "PRICE": round(random.random() * 100, 2)
        }
        for _ in range(100)
    ]

    app.producer_efficient_batch(events)