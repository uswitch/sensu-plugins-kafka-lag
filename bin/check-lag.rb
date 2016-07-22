#!/usr/bin/env ruby

require "zookeeper"
require "poseidon"
require "json"
require 'sensu-plugin/check/cli'

class CheckLag < Sensu::Plugin::Check::CLI

  option :zookeeper,
         short:       '-z ZOOKEEPER',
         long:        '--zookeeper ZOOKEEPER',
         description: "host:port of zookeeper"

  option :consumer_path,
         short:       '-p CONSUMER_PATH',
         long:        '--consumer-path CONSUMER_PATH',
         description: "Path of consumer name in zookeeper"

  option :consumer,
         short:       '-c CONSUMER',
         long:        '--consumer CONSUMER',
         description: "GroupId of Kafka consumer"

  option :topic,
         short:       '-t TOPIC',
         long:        '--topic TOPIC',
         description: "Name of Kafka topic"

  option :partition,
         short:       '-i PARTITION',
         long:        '--partition PARTITION',
         description: "Kafka partition id",
         default:     "0"

  option :threshold,
         short:       '-h THRESHOLD',
         long:        '--threshold THRESHOLD',
         description: "Consumer lag can be x behind latest threshold",
         default:     "0"

  option :n_times,
         short:       '-n N_TIMES',
         long:        '--n-times N_TIMES',
         description: "Number of times to evaluate before fail",
         default:     "5"

  option :interval,
         short:       '-i INTERVAL',
         long:        '--interval INTERVAL',
         description: "Interval to wait between checks",
         default:     "5"

  def ensure_arg(k)
    v = config[k]
    raise "Arg #{k} is required" unless v
    v
  end

  def resolve_consumer_name(zk, path)
    STDOUT.puts "Getting Current Consumer GroupId from Zookeeper"
    consumer = zk.get(path: path)[:data]
    STDOUT.puts "Successfully got zk: #{path} to: #{consumer}"
    consumer
  end

  def committed_offset(zk, consumer, topic, partition)
    path = "/consumers/#{consumer}/offsets/#{topic}/#{partition}"
    zk.get(path: path)[:data].to_i
  end

  def leader_broker(zk, topic, partition)
    state = zk.get(path: "/brokers/topics/#{topic}/partitions/#{partition}/state")
    leader = JSON.parse(state[:data])["leader"]
    JSON.parse(zk.get(path: "/brokers/ids/#{leader}")[:data])
  end

  def latest_offset(zk, topic, partition)
    broker = leader_broker zk, topic, partition
    consumer = Poseidon::PartitionConsumer.new("ConsumerOffsetChecker",
                                               broker["host"],
                                               broker["port"],
                                               topic,
                                               partition,
                                               :latest_offset)
    consumer.fetch
    consumer.highwater_mark
  end

  def check(zk, consumer, topic, partition, threshold, n_times, n, interval, init)
    STDOUT.puts "Checking offsets, n = #{n}"
    leader_offset   = latest_offset zk, topic, partition
    consumer_offset = committed_offset zk, consumer, topic, partition
    init ||= consumer_offset
    STDOUT.puts "Leader latest offset       = #{leader_offset}"
    STDOUT.puts "Consumer's commited offset = #{consumer_offset}"
    STDOUT.puts "Initial offset             = #{init}"
    if consumer_offset < (leader_offset - threshold)
      if init == consumer_offset && n == n_times
        :critical
      elsif init < consumer_offset
        :warning
      else
        sleep interval
        check zk, consumer, topic, partition, n_times, n + 1, interval, init
      end
    else
      :ok
    end
  end

  def run
    partition     = ensure_arg(:partition).to_i
    n_times       = ensure_arg(:n_times).to_i
    interval      = ensure_arg(:interval).to_i
    threshold     = ensure_arg(:threshold).to_i
    topic         = ensure_arg(:topic)

    consumer      = config[:consumer]
    consumer_path = config[:consumer_path]

    zookeeper     = ensure_arg(:zookeeper)

    zk = Zookeeper.new(zookeeper)

    consumer ||= consumer_path ? resolve_consumer_name(zk, consumer_path) : nil

    raise "Either `consumer` or `consumer_path` must be set" unless consumer

    status = check zk,
                   consumer,
                   topic,
                   partition,
                   threshold,
                   n_times,
                   1,
                   interval,
                   nil

    if status == :critical
      critical "Consumer #{consumer} is lagging, and has stopped advancing"
    elsif status == :warning
      warning "Consumer #{consumer} is lagging"
    else
      ok "Consumer #{consumer} is up-to-date"
    end
  end
end
