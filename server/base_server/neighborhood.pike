#define DELAY 10

mapping neighborhood = ([ ]);
object udp_broad=spider.dumUDP();

void got_info()
{
  mapping m = decode_value(udp_broad->read()->data);
  neighborhood[m->configurl]=m;
}

string network_number()
{
  return roxen->query("neigh_ip");
}

void broadcast()
{
  udp_broad->
    send(network_number(),51521,
	 encode_value((["configurl":roxen->config_url(),
			"host":gethostname(),
		     	"uid":getuid(),
			"comment":roxen->query("neigh_com"),
			"server_urls":Array.map(roxen->configurations,
				   lambda(object c)  {
			  return c->query("MyWorldLocation");
			})
		      ])));
  call_out(broadcast,30);
}

void create()
{
  udp_broad->bind(51521);
  udp_broad->set_read_callback(got_info);
  if(roxen->query("neighborhood"))
     broadcast();
  add_constant("neighborhood", neighborhood);
}
