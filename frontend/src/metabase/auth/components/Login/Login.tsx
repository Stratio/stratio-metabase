import type { Location } from "history";
import { t } from "ttag";

import { useSelector } from "metabase/lib/redux";
import type { AuthProvider } from "metabase/plugins/types";
import { getApplicationName } from "metabase/selectors/whitelabel";
import { Box } from "metabase/ui";

// < STRATIO import getSSOEnabled selector and AuthButton
import {
  getAuthProviders,
  getSSOEnabled,
  getStratioLogoutUrl,
} from "../../selectors";
import { AuthButton } from "../AuthButton";
// STRATIO >
import { AuthLayout } from "../AuthLayout";

interface LoginQueryString {
  redirect?: string;
}

interface LoginQueryParams {
  provider?: string;
}

interface LoginProps {
  params?: LoginQueryParams;
  location?: Location<LoginQueryString>;
}

export const Login = ({ params, location }: LoginProps): JSX.Element => {
  const providers = useSelector(getAuthProviders);
  const selection = getSelectedProvider(providers, params?.provider);
  const redirectUrl = location?.query?.redirect;
  const applicationName = useSelector(getApplicationName);
  const gosecSSOEnabled = useSelector(getSSOEnabled);
  const stratioLogoutUrl = useSelector(getStratioLogoutUrl);

  // < STRATIO - login via headers/jwt - do not show login form
  // if we reach here it means we have jwt but we are not allowed so no session => 401 => routed to auth/login
  if (gosecSSOEnabled) {
    return (
      <AuthLayout>
        <Box
          role="heading"
          c="text-dark"
          fz="1.25rem"
          fw="bold"
          lh="1.5rem"
          ta="center"
        >
          {t`You are not allowed to access ${applicationName}`}
        </Box>
        <AuthButton
          isCard={true}
          onClick={() => (window.location.href = stratioLogoutUrl)}
        >
          {"Logout"}
        </AuthButton>
      </AuthLayout>
    );
  }
  //  STRATIO >
  else {
    return (
      <AuthLayout>
        <Box
          role="heading"
          c="text-dark"
          fz="1.25rem"
          fw="bold"
          lh="1.5rem"
          ta="center"
        >
          {t`Sign in to ${applicationName}`}
        </Box>
        {selection && selection.Panel && (
          <Box mt="2.5rem">
            <selection.Panel redirectUrl={redirectUrl} />
          </Box>
        )}
        {!selection && (
          <Box mt="3.5rem">
            {providers.map(provider => (
              <Box key={provider.name} mt="2rem" ta="center">
                <provider.Button isCard={true} redirectUrl={redirectUrl} />
              </Box>
            ))}
          </Box>
        )}
      </AuthLayout>
    );
  }
};

const getSelectedProvider = (
  providers: AuthProvider[],
  providerName?: string,
): AuthProvider | undefined => {
  const provider =
    providers.length > 1
      ? providers.find(p => p.name === providerName)
      : providers[0];

  return provider?.Panel ? provider : undefined;
};
