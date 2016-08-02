// IPython kernel backend in C#
// Doug Blank
using System;
using System.Text;
using System.IO;
using System.Threading;
using ZeroMQ;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;

// CustomCreationConverter
using System.Collections.Generic; // IDictionary
using System.Security.Cryptography;

// IList
using System.Collections;
using System.Reflection;// IEnumerator

public class SimpleKernel
{
    public static Session session;

    [STAThread]
    public static void Main(string[] args)
    {
        Console.Error.WriteLine(String.Format("Filename: {0}", args[0]));
        Start(args[0]);
    }

    public static Dictionary<string, object> dict(params object[] args)
    {
        var retval = new Dictionary<string, object>();
        for (int i = 0; i < args.Length; i += 2)
        {
            retval[args[i].ToString()] = args[i + 1];
        }
        return retval;
    }

    public static List<string> list(params object[] args)
    {
        var retval = new List<string>();
        foreach (object arg in args)
        {
            retval.Add(arg.ToString());
        }
        return retval;
    }

    public static List<byte[]> blist(params byte[][] args)
    {
        var retval = new List<byte[]>();
        foreach (byte[] arg in args)
        {
            retval.Add(arg);
        }
        return retval;
    }

    public static IDictionary<string, object> decode(string json)
    {
        return JsonConvert.DeserializeObject<IDictionary<string, object>>(
               json, new JsonConverter[] { new MyConverter() });
    }

    public static void Start(string config_file)
    {
        session = new Session(config_file);
        GLib.ExceptionManager.UnhandledException += session.HandleException;
        config_file = session.filename;
        session.start();
        while (true)
        {
            if (session.need_restart)
            {
                session.need_restart = false;
                session.stop();
                session = new Session(config_file);
                session.start();
            }
            if (session.request_quit)
            {
                session.stop();
                System.Environment.Exit(0);
            }
            Thread.Sleep((int)(1 * 1000)); // seconds
        }
    }

    public class Authorization
    {
        public string secure_key;
        public string digestmod;
        HMACSHA256 hmac;

        public Authorization(string secure_key, string digestmod)
        {
            this.secure_key = secure_key;
            this.digestmod = digestmod;
            hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secure_key));
        }

        public string sign(List<string> list)
        {
            hmac.Initialize();
            foreach (string item in list)
            {
                byte[] sourcebytes = Encoding.UTF8.GetBytes(item);
                hmac.TransformBlock(sourcebytes, 0, sourcebytes.Length, null, 0);
            }
            hmac.TransformFinalBlock(new byte[0], 0, 0);
            return BitConverter.ToString(hmac.Hash).Replace("-", "").ToLower();
        }
    }

    class MyConverter : CustomCreationConverter<IDictionary<string, object>>
    {
        public override IDictionary<string, object> Create(Type objectType)
        {
            return new Dictionary<string, object>();
        }

        public override bool CanConvert(Type objectType)
        {
            return objectType == typeof(object) || base.CanConvert(objectType);
        }

        public override object ReadJson(JsonReader reader,
                                             Type objectType,
                                             object existingValue,
                                             JsonSerializer serializer)
        {
            if ((reader.TokenType == JsonToken.StartObject) ||
            (reader.TokenType == JsonToken.Null))
            {
                return base.ReadJson(reader, objectType, existingValue, serializer);
            }
            else
            {
                return serializer.Deserialize(reader);
            }
        }
    }

    public class Session
    {
        internal bool blocking = true;
        public bool need_restart = false;
        public bool request_quit = false;
        public string filename;
        public HeartBeatChannel hb_channel;
        public ShellChannel shell_channel;
        public IOPubChannel iopub_channel;
        public ControlChannel control_channel;
        public StdInChannel stdin_channel;
        public Authorization auth;
        public string engine_identity;
        public int engine_identity_int = -1;
        public int current_execution_count = 0;
        public IDictionary<string, object> parent_header;
        public IDictionary<string, object> config;
        public System.IO.StreamWriter log;
        public bool rich_display = false;

        public Session(string filename)
        {
            this.filename = filename;
            engine_identity = System.Guid.NewGuid().ToString();
            string json;
            if (this.filename != "")
            {
                json = File.ReadAllText(this.filename);
                config = decode(json);
                Console.Error.WriteLine(String.Format("config: {0}", config["transport"]));
                Console.Error.WriteLine(String.Format("config: {0}", config["ip"]));
                Console.Error.WriteLine(String.Format("config: {0}", config["hb_port"]));
            }
            else
            {
                config = dict("key", System.Guid.NewGuid().ToString(),
                                       "signature_scheme", "hmac-sha256",
                                       "transport", "tcp",
                                       "ip", "127.0.0.1",
                                       "hb_port", "0",
                                       "shell_port", "0",
                                       "iopub_port", "0",
                                       "control_port", "0",
                                       "stdin_port", "0");
            }
            auth = new Authorization(config["key"].ToString(),
                                          config["signature_scheme"].ToString());
            hb_channel = new HeartBeatChannel(this, auth,
                                                   config["transport"].ToString(),
                                                   config["ip"].ToString(),
                                                   config["hb_port"].ToString());
            shell_channel = new ShellChannel(this, auth,
                                                  config["transport"].ToString(),
                                                  config["ip"].ToString(),
                                                  config["shell_port"].ToString());
            iopub_channel = new IOPubChannel(this, auth,
                                                  config["transport"].ToString(),
                                                  config["ip"].ToString(),
                                                  config["iopub_port"].ToString());
            control_channel = new ControlChannel(this, auth,
                                                      config["transport"].ToString(),
                                                      config["ip"].ToString(),
                                                      config["control_port"].ToString());
            stdin_channel = new StdInChannel(this, auth,
                                                  config["transport"].ToString(),
                                                  config["ip"].ToString(),
                                                  config["stdin_port"].ToString());

            if (this.filename == "")
            {
                config["hb_port"] = hb_channel.port;
                config["shell_port"] = shell_channel.port;
                config["iopub_port"] = iopub_channel.port;
                config["control_port"] = control_channel.port;
                config["stdin_port"] = stdin_channel.port;
                string kernelname = String.Format("kernel-{0}.json",
                                                           System.Diagnostics.Process.GetCurrentProcess().Id);
                string ipython_config = ("{{\n" +
                             "  \"hb_port\": {0},\n" +
                             "  \"shell_port\": {1},\n" +
                             "  \"iopub_port\": {2},\n" +
                             "  \"control_port\": {3},\n" +
                             "  \"stdin_port\": {4},\n" +
                             "  \"ip\": \"{5}\",\n" +
                             "  \"signature_scheme\": \"{6}\",\n" +
                             "  \"key\": \"{7}\",\n" +
                             "  \"transport\": \"{8}\"\n" +
                             "}}");
                ipython_config = String.Format(ipython_config,
                                                        config["hb_port"],
                                                        config["shell_port"],
                                                        config["iopub_port"],
                                                        config["control_port"],
                                                        config["stdin_port"],
                                                        config["ip"],
                                                        config["signature_scheme"],
                                                        config["key"],
                                                        config["transport"]);
                System.IO.StreamWriter sw = new System.IO.StreamWriter(this.filename);
                sw.Write(ipython_config);
                sw.Close();
                Console.Error.WriteLine("IPython config file written to:");
                Console.Error.WriteLine("   \"{0}\"", this.filename);
                Console.Error.WriteLine("To exit, you will have to explicitly quit this process, by either sending");
                Console.Error.WriteLine("\"quit\" from a client, or using Ctrl-\\ in UNIX-like environments.");
                Console.Error.WriteLine("To read more about this, see https://github.com/ipython/ipython/issues/2049");
                Console.Error.WriteLine("To connect another client to this kernel, use:");
                Console.Error.WriteLine("    --existing {0} --profile calico", kernelname);
            }
        }

        public static Dictionary<string, object> Header(string msg_type)
        {
            var retval = new Dictionary<string, object>();
            retval["date"] = now();
            retval["msg_id"] = msg_id();
            retval["username"] = "kernel";
            retval["session"] = session.engine_identity;
            retval["msg_type"] = msg_type;
            return retval;
        }

        public static string encode(IDictionary<string, object> dict)
        {
            return JsonConvert.SerializeObject(dict);
        }

        public static string now()
        {
            return DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.ffffff");
        }

        public static string msg_id()
        {
            return System.Guid.NewGuid().ToString();
        }

        public void SetBlocking(bool blocking)
        {
            this.blocking = blocking;
        }

        public void SetRichDisplay(bool value)
        {
            this.rich_display = value;
        }

        public bool GetRichDisplay()
        {
            return this.rich_display;
        }

        public void HandleException(GLib.UnhandledExceptionArgs args)
        {
            Console.Error.WriteLine(String.Format("Exception: {0}", args.ExceptionObject.ToString()));
        }

        public bool GetBlocking()
        {
            return blocking;
        }

        public string TitleCase(string text)
        {
            return char.ToUpper(text[0]) + text.Substring(1);
        }

        public void start()
        {
            hb_channel.thread.Start();
            shell_channel.thread.Start();
            control_channel.thread.Start();
            stdin_channel.thread.Start();
        }

        public void stop()
        {
            try
            {
                hb_channel.stop();
                shell_channel.stop();
                control_channel.stop();
                stdin_channel.stop();
            }
            catch
            {
                // ignore errors, shutting down
            }
        }

        public void send(Channel channel,
                              string msg_type,
                  IList<byte[]> identities,
                  IDictionary<string, object> parent_header,
                  IDictionary<string, object> metadata,
                  IDictionary<string, object> content
                  )
        {
            send(channel,
              msg_type,
              identities,
              encode(parent_header),
              encode(metadata),
              encode(content));
        }

        public void send(Channel channel,
                              string msg_type,
                  IList<byte[]> identities,
                              string parent_header,
                              string metadata,
                              string content)
        {

            Console.Error.WriteLine(String.Format("send: {0}", msg_type));
            string header = encode(Header(msg_type));
            string signature = auth.sign(new List<string>() {
                    header, parent_header, metadata, content});
            List<string> parts = list("<IDS|MSG>",
                                           signature,
                                           header,
                                           parent_header,
                                           metadata,
                                           content);
            foreach (byte[] msg in identities)
            {
                Console.Error.WriteLine(String.Format("send ident: {0}", msg));
                channel.socket.SendMore(msg);
            }
            int count = 0;
            foreach (string msg in parts)
            {
                Console.Error.WriteLine(String.Format("send parts: {0}", msg));
                if (count < parts.Count - 1)
                {
                    channel.socket.SendMore(msg, Encoding.UTF8);
                }
                else
                {
                    channel.socket.Send(msg, Encoding.UTF8);
                }
                count++;
            }
        }
    }

    public class Channel
    {
        public Session session;
        public string transport;
        public string address;
        public ZmqContext context;
        public ZmqSocket socket;
        public string port;
        public Authorization auth;
        public Thread thread;
        string state = "normal"; // "waiting", "ready"
        public string reply = "";

        public Channel(Session session,
                            Authorization auth,
                            string transport,
                            string address,
                            string port,
                            SocketType socket_type)
        {
            this.session = session;
            this.auth = auth;
            this.transport = transport;
            this.address = address;
            this.port = port;
            context = ZmqContext.Create();
            socket = context.CreateSocket(socket_type);
            if (port == "0")
            {
                Random rand = new Random();
                int min_port = 49152;
                int max_port = 65536;
                int max_tries = 100;
                int p = 0;
                int i;
                for (i = 0; i < max_tries; i++)
                {
                    p = rand.Next(min_port, max_port);
                    string addr = String.Format("{0}://{1}:{2}",
                                                         this.transport, this.address, p);
                    try
                    {
                        socket.Bind(addr);
                    }
                    catch
                    {
                        continue;
                    }
                    break;
                }
                if (i == 100)
                {
                    throw new Exception("Exhausted tries looking for random port");
                }
                this.port = "" + p;
            }
            else
            {
                socket.Bind(String.Format("{0}://{1}:{2}",
                                                    this.transport, this.address, this.port));
            }
            socket.Identity = Encoding.UTF8.GetBytes(session.engine_identity);
            thread = new Thread(new ThreadStart(loop));
        }

        public void SetState(string newstate, string result)
        {
            lock (state)
            {
                state = newstate;
                reply = result;
            }
        }

        public string GetState()
        {
            lock (state)
            {
                return state;
            }
        }

        static byte[] GetBytes(string str)
        {
            byte[] bytes = new byte[str.Length * sizeof(char)];
            System.Buffer.BlockCopy(str.ToCharArray(), 0, bytes, 0, bytes.Length);
            return bytes;
        }

        public virtual void loop()
        {
            string signature, s_header, s_parent_header, s_metadata, s_content;
            byte[] bmessage = new byte[100];
            int size;
            List<byte[]> identities;
            while (!session.request_quit)
            {
                Console.Error.WriteLine(String.Format("loop()"));
                identities = new List<byte[]>();
                var MyEncoding = System.Text.Encoding.GetEncoding("windows-1252");
                size = socket.Receive(bmessage);//    (MyEncoding);
                Console.Error.WriteLine(String.Format("Receive: {0}", MyEncoding.GetString(bmessage, 0, size)));
                while (MyEncoding.GetString(bmessage, 0, size) != "<IDS|MSG>")
                {
                    byte[] buffer = new byte[size];
                    for (int i = 0; i < size; i++)
                    {
                        buffer[i] = bmessage[i];
                    }
                    identities.Add(buffer);
                    size = socket.Receive(bmessage);
                    Console.Error.WriteLine(String.Format("Receive: {0}", MyEncoding.GetString(bmessage, 0, size)));

                }
                signature = socket.Receive(Encoding.UTF8);
                s_header = socket.Receive(Encoding.UTF8);
                s_parent_header = socket.Receive(Encoding.UTF8);
                s_metadata = socket.Receive(Encoding.UTF8);
                s_content = socket.Receive(Encoding.UTF8);
                string comp_sig = auth.sign(new List<string>() {
            s_header, s_parent_header, s_metadata, s_content});

                if (comp_sig != signature)
                {
                    throw new Exception("Error: signatures don't match!");
                }

                IDictionary<string, object> header = decode(s_header);
                IDictionary<string, object> parent_header = decode(s_parent_header);
                IDictionary<string, object> metadata = decode(s_metadata);
                IDictionary<string, object> content = decode(s_content);
                Console.Error.WriteLine(String.Format("msg_type: {0}", header["msg_type"]));
                on_recv(identities, signature, header, parent_header, metadata, content);
            }
        }

        public virtual void on_recv(List<byte[]> identities,
                                         string m_signature,
                                         IDictionary<string, object> m_header,
                                         IDictionary<string, object> m_parent_header,
                                         IDictionary<string, object> m_metadata,
                                         IDictionary<string, object> m_content)
        {
            //throw new Exception(this.ToString() + ": unknown msg_type: " + m_header["msg_type"]);
        }

        public void stop()
        {
            thread.Abort();
            socket.Linger = System.TimeSpan.FromSeconds(1);
            socket.Close();
            //context.Terminate();
        }
    }

    public class ShellChannel : Channel
    {
        public int execution_count = 1;

        public ShellChannel(Session session,
                                 Authorization auth,
                                 string transport,
                                 string address,
                                 string port) :
                base(session, auth, transport, address, port, SocketType.ROUTER)
        {
        }

        // Shell
        public override void on_recv(List<byte[]> identities,
                                          string m_signature,
                                          IDictionary<string, object> m_header,
                                          IDictionary<string, object> m_parent_header,
                                          IDictionary<string, object> m_metadata,
                                          IDictionary<string, object> m_content)
        {
            // Shell handler
            string msg_type = m_header["msg_type"].ToString();
            if (msg_type == "execute_request")
            {
                var metadata = dict();
                var content = dict("execution_state", "busy");
                session.send(session.iopub_channel, "status",
                          blist(), m_header, metadata, content);
                // ---------------------------------------------------
                metadata = dict();
                content = dict("execution_count", execution_count,
                        "code", m_content["code"].ToString());
                session.send(session.iopub_channel, "pyin",
                          blist(), m_header, metadata, content);
                // ---------------------------------------------------
                metadata = dict();
                content = dict("execution_count", execution_count,
                        "data", dict("text/plain", "result!"),
                        "metadata", dict());
                session.send(session.iopub_channel, "pyout",
                          blist(), m_header, metadata, content);
                // ---------------------------------------------------
                metadata = dict();
                content = dict("execution_state", "idle");
                session.send(session.iopub_channel, "status",
                          blist(), m_header, metadata, content);
                metadata = dict(
                         "dependencies_met", true,
                         "engine", session.engine_identity,
                         "status", "ok",
                         "started", Session.now()
                         );
                content = dict(
                        "status", "ok",
                        "execution_count", execution_count,
                        "user_variables", dict(),
                        "payload", blist(),
                        "user_expressions", dict()
                        );
                session.send(session.shell_channel, "execute_reply",
                          identities, m_header, metadata, content);
            }
            else if (msg_type == "kernel_info_request")
            {
                var metadata = dict();
                var content = dict("protocol_version", new List<int>() { 4, 0 },
                            "ipython_version", new List<object>() { 1, 1, 0, "" },
                            "language_version", new List<int>() { 0, 0, 1 },
                            "language", "SimpleKernel");
                session.send(session.shell_channel,
                          "kernel_info_reply",
                          identities, m_header, metadata, content);
            }
            else
            {
                //throw new Exception("ShellChannel: unknown msg_type: " + msg_type);
            }
        }
    }

    public class IOPubChannel : Channel
    {
        public IOPubChannel(Session session,
                                 Authorization auth,
                                 string transport,
                                 string address,
                                 string port) :
                base(session, auth, transport, address, port, SocketType.PUB)
        {
        }
    }

    public class ControlChannel : Channel
    {
        public ControlChannel(Session session,
                                   Authorization auth,
                                   string transport,
                                   string address,
                                   string port) :
                base(session, auth, transport, address, port, SocketType.ROUTER)
        {
        }

        public override void on_recv(List<byte[]> identities,
                                          string m_signature,
                                          IDictionary<string, object> m_header,
                                          IDictionary<string, object> m_parent_header,
                                          IDictionary<string, object> m_metadata,
                                          IDictionary<string, object> m_content)
        {
            // Control handler
            string msg_type = m_header["msg_type"].ToString();
            if (msg_type == "shutdown_request")
            {
                session.request_quit = true;
            }
            else
            {
            }
        }
    }

    public class StdInChannel : Channel
    {

        public StdInChannel(Session session,
                                 Authorization auth,
                                 string transport,
                                 string address,
                                 string port) :
                base(session, auth, transport, address, port, SocketType.ROUTER)
        {
        }


        // StdIn
        public override void on_recv(List<byte[]> identities,
                                          string m_signature,
                                          IDictionary<string, object> m_header,
                                          IDictionary<string, object> m_parent_header,
                                          IDictionary<string, object> m_metadata,
                                          IDictionary<string, object> m_content)
        {
            // StdIn handler
            string msg_type = m_header["msg_type"].ToString();
            if (msg_type == "input_reply")
            {
                SetState("ready", m_content["value"].ToString());
            }
            else
            {
            }
        }
    }

    public class HeartBeatChannel : Channel
    {
        public HeartBeatChannel(Session session,
                                     Authorization auth,
                                     string transport,
                                     string address,
                                     string port) :
                base(session, auth, transport, address, port, SocketType.REP)
        {
        }

        public override void loop()
        {
            while (!session.request_quit)
            {
                try
                {
                    string message = socket.Receive(Encoding.UTF8);
                    socket.Send(message, Encoding.UTF8);
                }
                catch
                {
                    break; // all done?
                }
            }
        }
    }
}


