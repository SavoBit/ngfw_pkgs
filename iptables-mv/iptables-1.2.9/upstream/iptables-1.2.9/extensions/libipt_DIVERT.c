/* Shared library add-on to iptables to add TPROXY target support. */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <getopt.h>

#include <iptables.h>
#include <linux/netfilter_ipv4/ip_tables.h>
#include <linux/netfilter_ipv4/ipt_DIVERT.h>

struct tosinfo {
    struct ipt_entry_target t;
    struct ipt_divert_target_info divert;
};

static void help(void)
{
    printf("DIVERT target v%s options:\n"
           "  --to-port port                   DIVERT packets to port\n",
           IPTABLES_VERSION);
}

static struct option opts[] = {
    { "to-port", 1, 0, '1' },
    { 0 }
};

static void init(struct ipt_entry_target *t, unsigned int *nfcache)
{}

static void parse_divert(const unsigned char *s, struct ipt_divert_target_info *info)
{
    int divert_port;
    string_to_number(s, 0, 65535, &divert_port);
    info->to_port = htons(divert_port);
}

static int parse(int c, char **argv, int invert, unsigned int *flags,
                 const struct ipt_entry *entry,
                 struct ipt_entry_target **target)
{
    struct ipt_divert_target_info *divertinfo
        = (struct ipt_divert_target_info *)(*target)->data;

    switch (c) {
    case '1':
        if (*flags)
            exit_error(PARAMETER_PROBLEM,"DIVERT target: Can't specify --to-port twice");
        parse_divert(optarg, divertinfo);
        *flags = 1;
        break;

    default:
        return 0;
    }

    return 1;
}

static void final_check(unsigned int flags)
{
    if (!flags)
        exit_error(PARAMETER_PROBLEM,
                   "DIVERT target: Parameter --to-port is required");
}

static void print(const struct ipt_ip *ip,
                  const struct ipt_entry_target *target,
                  int numeric)
{
    const struct ipt_divert_target_info *divertinfo =
        (const struct ipt_divert_target_info *)target->data;
    printf("DIVERT redirect %d", ntohs(divertinfo->to_port));
}

static void save(const struct ipt_ip *ip, const struct ipt_entry_target *target)
{
    const struct ipt_divert_target_info *divertinfo =
        (const struct ipt_divert_target_info *)target->data;

    printf("--to-port %d ", ntohs(divertinfo->to_port));
}

static 
struct iptables_target divert 
= { NULL,
    "DIVERT",
    IPTABLES_VERSION,
    IPT_ALIGN(sizeof(struct ipt_divert_target_info)),
    IPT_ALIGN(sizeof(struct ipt_divert_target_info)),
    &help,
    &init,
    &parse,
    &final_check,
    &print,
    &save,
    opts
};

void _init(void)
{
    register_target(&divert);
}
