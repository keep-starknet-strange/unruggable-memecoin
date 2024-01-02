import clsx from 'clsx'
import Box, { BoxProps } from 'src/theme/components/Box'

import * as styles from './style.css'

type ButtonProps = Omit<BoxProps, 'as'>

interface PrimaryButtonProps extends ButtonProps {
  major?: boolean
}

export const PrimaryButton = ({ className, major = false, children, ...props }: PrimaryButtonProps) => (
  <Box as="button" className={clsx(className, major ? styles.thirdDimension : styles.primaryButton)} {...props}>
    {major && <Box as="span" className={styles.thirdDimensionSpan} />}
    <Box zIndex="1" position="relative">
      {children}
    </Box>
  </Box>
)

interface SecondaryButtonProps extends ButtonProps {
  withIcon?: boolean
}

export const SecondaryButton = ({ className, withIcon, ...props }: SecondaryButtonProps) => (
  <Box as="button" className={clsx(className, styles.secondaryButton({ withIcon }))} {...props} />
)

export const IconButton = ({ className, ...props }: ButtonProps) => (
  <Box as="button" className={clsx(className, styles.iconButton)} {...props} />
)
