# 📊 Phoenix LiveDashboard Guide

## 🎯 What is LiveDashboard?

Phoenix LiveDashboard is a **real-time monitoring tool** built into Phoenix that shows you:
- 🧠 **CPU & Memory** usage
- 💾 **Database queries** (Ecto metrics) 
- 🔄 **Oban job queues** status
- ⚡ **Request/Response** times
- 🎮 **BEAM VM** internals (processes, schedulers, ports)

## 🚀 How to Access It

### Step 1: Start Your Server

In your terminal, run:

```bash
mix phx.server
```

Or if you prefer to run it in the background:

```bash
./dev_start.sh
```

### Step 2: Open the Dashboard

Once your server is running, open your browser and go to:

👉 **[http://localhost:4000/dashboard](http://localhost:4000/dashboard)**

That's it! The dashboard will load automatically.

---

## 📈 What You'll See

### 🏠 **Home Tab**
- Real-time request metrics
- Memory usage
- CPU load
- Running processes count

### 💾 **Ecto Stats Tab**
- Query counts
- Query timings
- Slowest queries
- Connection pool usage

### 📦 **Applications Tab**
- All running OTP applications
- Dependency versions

### 🔧 **Processes Tab**
- All running BEAM processes
- Memory per process
- Message queue lengths

### ⚙️ **Metrics Tab**
- Custom telemetry metrics defined in `lib/ledger_bank_api_web/telemetry.ex`
- Charts for:
  - Phoenix endpoint durations
  - Ecto query times
  - Oban job durations
  - VM metrics

---

## 🧪 Using It With Your Performance Tests

### Workflow:

1. **Start the server** in one terminal:
   ```bash
   mix phx.server
   ```

2. **Open the dashboard** in your browser:
   ```
   http://localhost:4000/dashboard
   ```

3. **Run your tests** in another terminal:
   ```bash
   # Run all tests
   mix test

   # Run just performance tests
   mix test test/ledger_bank_api/performance/

   # Run specific performance test
   mix test test/ledger_bank_api/performance/ecto_performance_test.exs

   # Run Oban stress tests
   mix test test/ledger_bank_api/performance/oban_stress_test.exs
   ```

4. **Watch the metrics** change live in the dashboard as tests run!

---

## 🔍 What to Look For During Tests

### 📊 Memory Spikes
- Look at the **Home** tab → **Memory** section
- If memory keeps growing = potential memory leak
- If memory goes up then down = normal GC behavior

### 🐢 Slow Queries
- Go to **Ecto Stats** tab
- Look for queries taking > 50ms
- These might need indexes or optimization

### 📬 Oban Queue Buildup
- Check **Metrics** tab
- Look for `oban.job.stop.duration` 
- If jobs take too long, you'll see it here

### 🔥 CPU Usage
- Check **Home** tab → **Scheduler Utilization**
- High utilization = CPU-bound work
- Low utilization with slow responses = IO-bound (DB, external APIs)

---

## 🎛️ Advanced: Add Custom Metrics

Your telemetry file is already set up! To add more metrics, edit:

📁 `lib/ledger_bank_api_web/telemetry.ex`

Example - Add a payment processing metric:

```elixir
def metrics do
  [
    # ... existing metrics ...
    
    # Your custom payment metric
    summary("ledger_bank_api.payment.process.duration",
      unit: {:native, :millisecond},
      tags: [:status, :user_id]
    ),
    
    counter("ledger_bank_api.payment.created.count",
      tags: [:direction, :payment_type]
    )
  ]
end
```

Then emit it from your code:

```elixir
:telemetry.execute(
  [:ledger_bank_api, :payment, :process],
  %{duration: duration_ms},
  %{status: payment.status, user_id: payment.user_id}
)
```

---

## 🛠️ Troubleshooting

### Dashboard doesn't load?

1. **Check server is running:**
   ```bash
   curl http://localhost:4000/health
   ```

2. **Check for compilation errors:**
   ```bash
   mix compile
   ```

3. **Try a different port:**
   Edit `config/dev.exs` and change the port, then restart.

### "Function not found" errors?

Make sure you have these dependencies in `mix.exs`:
```elixir
{:phoenix_live_dashboard, "~> 0.8.3"}
{:phoenix_live_view, "~> 0.20.0"}
```

Run `mix deps.get` if you added them.

---

## 🎥 Quick Demo Commands

Want to see the dashboard in action? Try this workflow:

```bash
# Terminal 1: Start server
mix phx.server

# Terminal 2: Create some load
# (After server starts, run this)
for i in {1..100}; do
  curl -X POST http://localhost:4000/api/users \
    -H "Content-Type: application/json" \
    -d '{
      "email": "user'$i'@test.com",
      "full_name": "Test User '$i'",
      "password": "password123",
      "password_confirmation": "password123"
    }'
done
```

Watch the dashboard while this runs — you'll see:
- Request count increase
- Database queries spike
- Memory usage grow
- Process count change

---

## 🎓 Learn More

- [Phoenix LiveDashboard Docs](https://hexdocs.pm/phoenix_live_dashboard)
- [Telemetry Guide](https://hexdocs.pm/phoenix/telemetry.html)
- [Oban Telemetry](https://hexdocs.pm/oban/Oban.Telemetry.html)

---

## 💡 Pro Tips

1. **Keep it open during development** - Spot performance issues early
2. **Compare before/after** optimization attempts
3. **Use it with load tests** - See internal impact of external pressure
4. **Export metrics** - Add Prometheus for long-term monitoring

---

**Happy monitoring! 🎉**

